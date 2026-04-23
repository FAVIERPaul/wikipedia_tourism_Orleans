from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from urllib.parse import quote, unquote, urlparse

import pandas as pd
import requests


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = PROJECT_ROOT / "data"
REFERENCES_DIR = DATA_DIR / "references"
DERIVED_DIR = DATA_DIR / "derived"

PAGES_PATH = REFERENCES_DIR / "wikipedia_pages.md"
ATTENDANCE_PATTERN = "daily_place_attendance_*.xlsx"
OUTPUT_BASENAME = "wikipedia_pageviews_fr"
USER_AGENT = "CodexReplicationMatter/1.0 (local data processing)"
API_ROOT = "https://wikimedia.org/api/rest_v1/metrics/pageviews/per-article/fr.wikipedia.org"
ACCESS_TYPES = ["desktop", "mobile-web", "mobile-app", "all-access"]
AGENT = "user"


@dataclass(frozen=True)
class WikiPage:
    lieu: str
    url: str
    article_title: str
    article_path: str


def parse_tracked_pages(path: Path) -> list[WikiPage]:
    lines = [line.strip() for line in path.read_text(encoding="utf-8").splitlines()]
    pages: list[WikiPage] = []
    index = 0
    while index < len(lines):
        line = lines[index]
        if not line or line.startswith("#"):
            index += 1
            continue
        if line.startswith("http"):
            index += 1
            continue

        lieu = line.rstrip("- ").strip()
        url = ""
        lookahead = index + 1
        while lookahead < len(lines):
            candidate = lines[lookahead]
            if candidate.startswith("http"):
                url = candidate
                break
            if candidate:
                break
            lookahead += 1

        if not url:
            raise SystemExit(f"Missing Wikipedia URL for place: {lieu}")

        parsed = urlparse(url)
        article_path = parsed.path.split("/wiki/", 1)[1]
        article_title = unquote(article_path).replace("_", " ")
        pages.append(
            WikiPage(
                lieu=lieu,
                url=url,
                article_title=article_title,
                article_path=article_path,
            )
        )
        index = lookahead + 1

    return pages


def find_reference_excel() -> Path:
    candidates = sorted(DERIVED_DIR.glob(ATTENDANCE_PATTERN), key=lambda path: path.stat().st_mtime, reverse=True)
    if not candidates:
        raise SystemExit("No daily attendance workbook was found to recover the analysis date range.")
    return candidates[0]


def extract_date_range(reference_excel: Path) -> tuple[pd.Timestamp, pd.Timestamp]:
    try:
        metadata = pd.read_excel(reference_excel, sheet_name="metadata")
        date_range = metadata.loc[metadata["key"] == "date_range", "value"]
        if not date_range.empty:
            start_raw, end_raw = [part.strip() for part in str(date_range.iloc[0]).split("->")]
            return pd.to_datetime(start_raw, dayfirst=True), pd.to_datetime(end_raw, dayfirst=True)
    except Exception:
        pass

    stem_parts = reference_excel.stem.rsplit("_", 2)
    if len(stem_parts) >= 3:
        start_raw, end_raw = stem_parts[-2], stem_parts[-1]
        return pd.to_datetime(start_raw), pd.to_datetime(end_raw)

    raise SystemExit("Unable to infer the date range from the reference workbook.")


def fetch_pageviews(
    session: requests.Session,
    article_path: str,
    access: str,
    start: pd.Timestamp,
    end: pd.Timestamp,
) -> pd.DataFrame:
    encoded_article = quote(unquote(article_path), safe="")
    start_str = start.strftime("%Y%m%d")
    end_str = end.strftime("%Y%m%d")
    url = f"{API_ROOT}/{access}/{AGENT}/{encoded_article}/daily/{start_str}/{end_str}"
    response = session.get(url, timeout=60)
    response.raise_for_status()
    payload = response.json()

    rows = []
    for item in payload.get("items", []):
        rows.append(
            {
                "jour": pd.to_datetime(item["timestamp"][:8], format="%Y%m%d"),
                "views": int(item["views"]),
            }
        )

    frame = pd.DataFrame(rows)
    if frame.empty:
        full_dates = pd.date_range(start, end, freq="D")
        return pd.DataFrame({"jour": full_dates, "views": 0})

    full_dates = pd.DataFrame({"jour": pd.date_range(start, end, freq="D")})
    frame = full_dates.merge(frame, on="jour", how="left")
    frame["views"] = frame["views"].fillna(0).astype(int)
    return frame


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
    pages = parse_tracked_pages(PAGES_PATH)
    reference_excel = find_reference_excel()
    start_date, end_date = extract_date_range(reference_excel)

    session = requests.Session()
    session.headers.update({"User-Agent": USER_AGENT})

    daily_tables: list[pd.DataFrame] = []
    page_rows: list[dict[str, str]] = []

    for page in pages:
        by_access: dict[str, pd.DataFrame] = {}
        for access in ACCESS_TYPES:
            access_frame = fetch_pageviews(
                session=session,
                article_path=page.article_path,
                access=access,
                start=start_date,
                end=end_date,
            ).rename(columns={"views": f"pv_user_{access.replace('-', '_')}"})
            by_access[access] = access_frame

        merged = by_access["desktop"]
        for access in ["mobile-web", "mobile-app", "all-access"]:
            merged = merged.merge(by_access[access], on="jour", how="left")

        merged["pv_user_mobile"] = merged["pv_user_mobile_web"] + merged["pv_user_mobile_app"]
        merged["pv_user_all_access_components"] = (
            merged["pv_user_desktop"] + merged["pv_user_mobile_web"] + merged["pv_user_mobile_app"]
        )
        merged["pv_user_all_access_delta"] = merged["pv_user_all_access"] - merged["pv_user_all_access_components"]
        merged.insert(1, "lieu", page.lieu)
        merged.insert(2, "wikipedia_url", page.url)
        merged.insert(3, "wikipedia_article", page.article_title)
        daily_tables.append(
            merged[
                [
                    "jour",
                    "lieu",
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
            ]
        )
        page_rows.append(
            {
                "lieu": page.lieu,
                "wikipedia_url": page.url,
                "wikipedia_article": page.article_title,
            }
        )

    output = pd.concat(daily_tables, ignore_index=True).sort_values(["jour", "lieu"]).reset_index(drop=True)
    output["jour"] = pd.to_datetime(output["jour"]).dt.strftime("%d/%m/%Y")
    pages_df = pd.DataFrame(page_rows)
    metadata = pd.DataFrame(
        [
            {"key": "project", "value": "fr.wikipedia.org"},
            {"key": "agent", "value": AGENT},
            {"key": "date_range", "value": f"{start_date.strftime('%d/%m/%Y')} -> {end_date.strftime('%d/%m/%Y')}"},
            {"key": "reference_excel", "value": reference_excel.name},
            {"key": "notes", "value": "pv_user_mobile = pv_user_mobile_web + pv_user_mobile_app"},
        ]
    )

    output_path = DERIVED_DIR / f"{OUTPUT_BASENAME}_{start_date.strftime('%Y-%m-%d')}_{end_date.strftime('%Y-%m-%d')}.xlsx"
    with pd.ExcelWriter(output_path, engine="openpyxl") as writer:
        output.to_excel(writer, sheet_name="daily_pageviews", index=False)
        pages_df.to_excel(writer, sheet_name="pages", index=False)
        metadata.to_excel(writer, sheet_name="metadata", index=False)

        for sheet_name, dataframe in {
            "daily_pageviews": output,
            "pages": pages_df,
            "metadata": metadata,
        }.items():
            worksheet = writer.book[sheet_name]
            worksheet.freeze_panes = "A2"
            worksheet.auto_filter.ref = worksheet.dimensions
            autosize_worksheet(worksheet, dataframe)

    print(f"Excel written: {output_path}")
    print(f"Rows: {len(output)}")
    print(f"Pages: {len(pages_df)}")


if __name__ == "__main__":
    main()
