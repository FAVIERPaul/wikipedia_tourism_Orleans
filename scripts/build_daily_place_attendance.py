from __future__ import annotations

import re
import unicodedata
from dataclasses import dataclass
from pathlib import Path

import pandas as pd


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = PROJECT_ROOT / "data"
RAW_DIR = DATA_DIR / "raw"
REFERENCES_DIR = DATA_DIR / "references"
DERIVED_DIR = DATA_DIR / "derived"

PAGES_PATH = REFERENCES_DIR / "wikipedia_pages.md"
SOURCE_PATH = RAW_DIR / "frequentation-par-heure.csv"
OUTPUT_BASENAME = "daily_place_attendance"

START_DATE = pd.Timestamp("2021-07-01")
SEGMENT_GAP_DAYS = 10
TEMPORARY_CLOSURE_DAYS = 7
WEEKDAY_WINDOW_DAYS = 70
CLOSED_RATIO_THRESHOLD = 0.15
MIN_WEEKDAY_OPPORTUNITIES = 6


@dataclass(frozen=True)
class Segment:
    segment_id: int
    start: pd.Timestamp
    end: pd.Timestamp


def normalize_name(value: str) -> str:
    normalized = unicodedata.normalize("NFKD", value)
    normalized = "".join(ch for ch in normalized if not unicodedata.combining(ch))
    normalized = normalized.upper().replace("'", " ").replace("-", " ")
    normalized = re.sub(r"[^A-Z0-9]+", " ", normalized)
    return re.sub(r"\s+", " ", normalized).strip()


PLACE_SOURCE_GROUPS = {
    normalize_name("Muséum d'Orléans"): ["MUSEUM D'ORLEANS"],
    normalize_name("Hôtel Groslot"): ["HOTEL GROSLOT"],
    normalize_name("Musée historique et archéologique de l'Orléanais"): [
        "MUSEE HISTORIQUE ET ARCHEOLOGIQUE DE L'ORLEANAIS - HOTEL CABU",
        "HOTEL CABU, MUSEE D'HISTOIRE ET D'ARCHEOLOGIE",
    ],
    normalize_name("Maison de Jeanne d'Arc"): ["MAISON DE JEANNE D'ARC"],
    normalize_name("Musée des Beaux-Arts d'Orléans"): [
        "MUSEE DES BEAUX ARTS",
        "MUSEE DES BEAUX-ARTS",
    ],
    normalize_name("Parc floral de la Source"): ["PARC FLORAL DE LA SOURCE"],
}

EXCLUDED_PLACES = {normalize_name("Ville d'Orlean")}


def extract_tracked_places(path: Path) -> list[str]:
    places: list[str] = []
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or line.startswith("http"):
            continue
        places.append(line.rstrip("- ").strip())
    return places


def load_daily_counts(path: Path) -> pd.DataFrame:
    df = pd.read_csv(path, sep=";", encoding="utf-8-sig", low_memory=False)
    entry_col = df.columns[0]
    df["jour"] = pd.to_datetime(df["horodatage"].astype(str).str[:10], errors="coerce")
    df[entry_col] = pd.to_numeric(df[entry_col], errors="coerce")
    df = df.dropna(subset=["jour", "Nom", entry_col]).copy()
    df = df.loc[df["jour"] >= START_DATE]
    daily = (
        df.groupby(["Nom", "jour"], as_index=False)[entry_col]
        .sum()
        .rename(columns={entry_col: "nombre_entrees"})
    )
    daily["nombre_entrees"] = daily["nombre_entrees"].round().astype("Int64")
    return daily


def build_place_mapping(tracked_places: list[str], available_names: set[str]) -> tuple[list[dict[str, object]], list[str]]:
    included_places: list[dict[str, object]] = []
    excluded_labels: list[str] = []

    for place in tracked_places:
        normalized_place = normalize_name(place)
        if normalized_place in EXCLUDED_PLACES:
            excluded_labels.append(place)
            continue

        source_names = PLACE_SOURCE_GROUPS.get(normalized_place)
        if not source_names:
            exact_match = [name for name in available_names if normalize_name(name) == normalized_place]
            source_names = exact_match

        valid_sources = [name for name in (source_names or []) if name in available_names]
        if not valid_sources:
            raise SystemExit(f"No matching CSV source was found for place: {place}")

        included_places.append(
            {
                "lieu": place,
                "configured_sources": list(source_names or []),
                "sources": valid_sources,
            }
        )

    return included_places, excluded_labels


def detect_segments(observed_dates: list[pd.Timestamp]) -> list[Segment]:
    if not observed_dates:
        return []

    segments: list[Segment] = []
    segment_start = observed_dates[0]
    previous = observed_dates[0]
    segment_id = 1

    for current in observed_dates[1:]:
        if (current - previous).days > SEGMENT_GAP_DAYS:
            segments.append(Segment(segment_id=segment_id, start=segment_start, end=previous))
            segment_id += 1
            segment_start = current
        previous = current

    segments.append(Segment(segment_id=segment_id, start=segment_start, end=previous))
    return segments


def extract_runs(day_index: pd.Index) -> list[tuple[pd.Timestamp, pd.Timestamp, int]]:
    if len(day_index) == 0:
        return []

    ordered = list(pd.to_datetime(day_index).sort_values())
    runs: list[tuple[pd.Timestamp, pd.Timestamp, int]] = []
    run_start = ordered[0]
    run_end = ordered[0]

    for current in ordered[1:]:
        if (current - run_end).days == 1:
            run_end = current
            continue

        runs.append((run_start, run_end, (run_end - run_start).days + 1))
        run_start = current
        run_end = current

    runs.append((run_start, run_end, (run_end - run_start).days + 1))
    return runs


def infer_place_table(place_name: str, observed_series: pd.Series, full_dates: pd.DatetimeIndex) -> pd.DataFrame:
    frame = pd.DataFrame(index=full_dates)
    frame.index.name = "jour"
    frame["lieu"] = place_name
    frame["nombre_entrees"] = observed_series.reindex(full_dates).astype("Float64")
    frame["status"] = "closed_or_inactive"
    frame["segment_id"] = pd.NA

    observed_dates = list(observed_series.index.sort_values())
    segments = detect_segments(observed_dates)

    for segment in segments:
        in_segment = (frame.index >= segment.start) & (frame.index <= segment.end)
        frame.loc[in_segment, "segment_id"] = segment.segment_id
        frame.loc[in_segment, "status"] = "in_segment"

    observed_mask = frame["nombre_entrees"].notna()
    frame.loc[observed_mask, "status"] = "observed"

    for segment in segments:
        segment_mask = frame["segment_id"] == segment.segment_id
        segment_frame = frame.loc[segment_mask].copy()
        missing_mask = segment_frame["nombre_entrees"].isna()

        if missing_mask.any():
            groups = (missing_mask != missing_mask.shift(fill_value=False)).cumsum()
            run_lengths = (
                segment_frame.loc[missing_mask]
                .groupby(groups[missing_mask], sort=False)
                .size()
            )
            long_runs = run_lengths[run_lengths >= TEMPORARY_CLOSURE_DAYS].index.tolist()
            if long_runs:
                temp_closed = missing_mask & groups.isin(long_runs)
                frame.loc[segment_frame.index[temp_closed], "status"] = "temporary_closure"

        segment_dates = segment_frame.index.to_series()
        for day in segment_frame.index[segment_frame["nombre_entrees"].isna()]:
            if frame.at[day, "status"] == "temporary_closure":
                continue

            day_distances = (segment_dates - day).abs().dt.days
            local_same_weekday = (
                (segment_dates.dt.weekday == day.weekday())
                & (day_distances <= WEEKDAY_WINDOW_DAYS)
            )
            local_window = segment_frame.loc[local_same_weekday.values]
            opportunities = len(local_window)
            observed_ratio = (
                local_window["nombre_entrees"].notna().sum() / opportunities
                if opportunities
                else 0
            )

            if opportunities >= MIN_WEEKDAY_OPPORTUNITIES and observed_ratio <= CLOSED_RATIO_THRESHOLD:
                frame.at[day, "status"] = "closure_pattern"
            else:
                frame.at[day, "status"] = "zero"
                frame.at[day, "nombre_entrees"] = 0

    frame["nombre_entrees"] = frame["nombre_entrees"].round().astype("Int64")
    return frame.reset_index()[["jour", "lieu", "nombre_entrees", "status"]]


def autosize_worksheet(worksheet, dataframe: pd.DataFrame) -> None:
    for idx, column_name in enumerate(dataframe.columns, start=1):
        sample = dataframe.iloc[:, idx - 1].head(5000)
        max_len = max(
            len(str(column_name)),
            max((len("" if pd.isna(value) else str(value)) for value in sample), default=0),
        )
        worksheet.column_dimensions[worksheet.cell(row=1, column=idx).column_letter].width = min(max_len + 2, 48)


def main() -> None:
    DERIVED_DIR.mkdir(parents=True, exist_ok=True)
    tracked_places = extract_tracked_places(PAGES_PATH)
    daily = load_daily_counts(SOURCE_PATH)
    available_names = set(daily["Nom"].dropna().unique().tolist())
    place_mappings, excluded_places = build_place_mapping(tracked_places, available_names)

    selected_source_names = sorted({source for item in place_mappings for source in item["sources"]})
    selected_daily = daily.loc[daily["Nom"].isin(selected_source_names)].copy()
    effective_end = selected_daily["jour"].max()
    full_dates = pd.date_range(START_DATE, effective_end, freq="D")

    tables: list[pd.DataFrame] = []
    mapping_rows: list[dict[str, str]] = []
    for item in place_mappings:
        place_name = str(item["lieu"])
        configured_sources = list(item["configured_sources"])
        sources = list(item["sources"])
        observed = (
            selected_daily.loc[selected_daily["Nom"].isin(sources), ["jour", "nombre_entrees"]]
            .groupby("jour", as_index=True)["nombre_entrees"]
            .sum()
            .sort_index()
            .astype("Int64")
        )
        tables.append(infer_place_table(place_name=place_name, observed_series=observed, full_dates=full_dates))
        mapping_rows.append(
            {
                "place": place_name,
                "configured_source_aliases": " | ".join(configured_sources),
                "observed_source_aliases_in_range": " | ".join(sources),
            }
        )

    enriched = pd.concat(tables, ignore_index=True).sort_values(["jour", "lieu"]).reset_index(drop=True)
    output = enriched[["jour", "lieu", "nombre_entrees"]].copy()
    output.loc[
        enriched["status"].isin({"closed_or_inactive", "closure_pattern", "temporary_closure", "zero"}),
        "nombre_entrees",
    ] = 0

    if output["nombre_entrees"].isna().any():
        raise SystemExit("The final output still contains missing attendance values.")

    output["nombre_entrees"] = output["nombre_entrees"].astype("Int64")
    output["jour"] = pd.to_datetime(output["jour"]).dt.strftime("%d/%m/%Y")

    temporary_closures = (
        enriched.loc[enriched["status"] == "temporary_closure", ["jour", "lieu"]]
        .sort_values(["lieu", "jour"])
        .reset_index(drop=True)
    )
    anomaly_rows: list[dict[str, object]] = []
    for place, group in temporary_closures.groupby("lieu"):
        for start, end, days in extract_runs(group["jour"]):
            anomaly_rows.append(
                {
                    "place": place,
                    "start": start.strftime("%d/%m/%Y"),
                    "end": end.strftime("%d/%m/%Y"),
                    "n_days": days,
                    "type": "temporary_closure_inferred",
                }
            )
    anomalies = pd.DataFrame(anomaly_rows)
    if anomalies.empty:
        anomalies = pd.DataFrame(columns=["place", "start", "end", "n_days", "type"])

    metadata = pd.DataFrame(
        [
            {"key": "date_range", "value": f"{START_DATE.strftime('%d/%m/%Y')} -> {effective_end.strftime('%d/%m/%Y')}"},
            {"key": "included_places", "value": str(len(place_mappings))},
            {"key": "excluded_places", "value": " | ".join(excluded_places) if excluded_places else ""},
            {"key": "segment_gap_days", "value": str(SEGMENT_GAP_DAYS)},
            {"key": "temporary_closure_days", "value": str(TEMPORARY_CLOSURE_DAYS)},
            {"key": "weekday_window_days", "value": str(WEEKDAY_WINDOW_DAYS)},
            {"key": "closed_ratio_threshold", "value": str(CLOSED_RATIO_THRESHOLD)},
            {"key": "min_weekday_opportunities", "value": str(MIN_WEEKDAY_OPPORTUNITIES)},
        ]
    )

    output_path = DERIVED_DIR / f"{OUTPUT_BASENAME}_{START_DATE.strftime('%Y-%m-%d')}_{effective_end.strftime('%Y-%m-%d')}.xlsx"
    mapping_df = pd.DataFrame(mapping_rows)

    with pd.ExcelWriter(output_path, engine="openpyxl") as writer:
        output.to_excel(writer, sheet_name="table", index=False)
        anomalies.to_excel(writer, sheet_name="anomalies", index=False)
        mapping_df.to_excel(writer, sheet_name="mapping", index=False)
        metadata.to_excel(writer, sheet_name="metadata", index=False)

        for sheet_name, dataframe in {
            "table": output,
            "anomalies": anomalies,
            "mapping": mapping_df,
            "metadata": metadata,
        }.items():
            worksheet = writer.book[sheet_name]
            worksheet.freeze_panes = "A2"
            worksheet.auto_filter.ref = worksheet.dimensions
            autosize_worksheet(worksheet, dataframe)

    print(f"Excel written: {output_path}")
    print(f"Rows in table sheet: {len(output)}")
    print(f"Excluded places: {', '.join(excluded_places) if excluded_places else 'none'}")


if __name__ == "__main__":
    main()
