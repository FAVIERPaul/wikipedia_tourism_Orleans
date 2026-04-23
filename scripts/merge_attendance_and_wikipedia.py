from __future__ import annotations

from pathlib import Path

import pandas as pd


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DERIVED_DIR = PROJECT_ROOT / "data" / "derived"
LOCAL_PATTERN = "daily_place_attendance_*.xlsx"
WIKI_PATTERN = "wikipedia_pageviews_fr_*.xlsx"
EXCLUDED_PLACE = "Ville d'Orlean"
OUTPUT_BASENAME = "merged_attendance_wikipedia_fr"


def find_latest(pattern: str) -> Path:
    candidates = sorted(DERIVED_DIR.glob(pattern), key=lambda path: path.stat().st_mtime, reverse=True)
    if not candidates:
        raise SystemExit(f"No file was found for pattern: {pattern}")
    return candidates[0]


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
    local_file = find_latest(LOCAL_PATTERN)
    wiki_file = find_latest(WIKI_PATTERN)

    local_df = pd.read_excel(local_file, sheet_name="table")
    wiki_df = pd.read_excel(wiki_file, sheet_name="daily_pageviews")

    local_df["date_dt"] = pd.to_datetime(local_df["jour"], dayfirst=True)
    wiki_df["date_dt"] = pd.to_datetime(wiki_df["jour"], dayfirst=True)

    wiki_df = wiki_df.loc[wiki_df["lieu"] != EXCLUDED_PLACE].copy()

    local_dupes = local_df.duplicated(subset=["date_dt", "lieu"]).sum()
    wiki_dupes = wiki_df.duplicated(subset=["date_dt", "lieu"]).sum()
    if local_dupes or wiki_dupes:
        raise SystemExit(f"Duplicate keys detected before merge. local={local_dupes}, wiki={wiki_dupes}")

    merged = local_df.merge(
        wiki_df,
        on=["date_dt", "lieu"],
        how="inner",
        suffixes=("_local", "_wiki"),
    )

    expected_rows = len(local_df)
    if len(merged) != expected_rows:
        missing_rows = expected_rows - len(merged)
        raise SystemExit(
            f"The merge is incomplete. Expected rows={expected_rows}, obtained rows={len(merged)}, missing={missing_rows}"
        )

    merged = merged.sort_values(["date_dt", "lieu"]).reset_index(drop=True)
    merged = merged[
        [
            "jour_local",
            "lieu",
            "nombre_entrees",
            "wikipedia_url",
            "wikipedia_article",
            "pv_user_mobile",
            "pv_user_desktop",
            "pv_user_mobile_web",
            "pv_user_mobile_app",
            "pv_user_all_access",
            "pv_user_all_access_components",
            "pv_user_all_access_delta",
        ]
    ].rename(columns={"jour_local": "jour"})

    metadata = pd.DataFrame(
        [
            {"key": "local_source_file", "value": local_file.name},
            {"key": "wikipedia_source_file", "value": wiki_file.name},
            {"key": "excluded_place", "value": EXCLUDED_PLACE},
            {"key": "join_keys", "value": "jour + lieu"},
            {"key": "rows_merged", "value": str(len(merged))},
            {"key": "places_merged", "value": str(merged["lieu"].nunique())},
            {"key": "date_range", "value": f"{merged['jour'].iloc[0]} -> {merged['jour'].iloc[-1]}"},
        ]
    )

    places = (
        merged[["lieu", "wikipedia_article", "wikipedia_url"]]
        .drop_duplicates()
        .sort_values("lieu")
        .reset_index(drop=True)
    )

    output_name = f"{OUTPUT_BASENAME}_{local_file.stem.split('daily_place_attendance_', 1)[1]}.xlsx"
    output_path = DERIVED_DIR / output_name

    with pd.ExcelWriter(output_path, engine="openpyxl") as writer:
        merged.to_excel(writer, sheet_name="merged", index=False)
        places.to_excel(writer, sheet_name="places", index=False)
        metadata.to_excel(writer, sheet_name="metadata", index=False)

        for sheet_name, dataframe in {
            "merged": merged,
            "places": places,
            "metadata": metadata,
        }.items():
            worksheet = writer.book[sheet_name]
            worksheet.freeze_panes = "A2"
            worksheet.auto_filter.ref = worksheet.dimensions
            autosize_worksheet(worksheet, dataframe)

    print(f"Excel written: {output_path}")
    print(f"Merged rows: {len(merged)}")
    print(f"Places: {merged['lieu'].nunique()}")


if __name__ == "__main__":
    main()
