from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

import financedatabase as fd
import pandas as pd


ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "data" / "markets"
OUT_DIR.mkdir(parents=True, exist_ok=True)

PARQUET_PATH = OUT_DIR / "global_universe.parquet"
CSV_PATH = OUT_DIR / "global_universe.csv"
SUMMARY_PATH = OUT_DIR / "global_universe_summary.json"

OUTPUT_COLUMNS = [
    "symbol",
    "name",
    "asset_type",
    "country",
    "region",
    "exchange",
    "market",
    "currency",
    "isin",
    "provider",
    "is_active",
]

COUNTRY_ALIASES = {
    "US": "United States",
    "USA": "United States",
    "U.S.": "United States",
    "U.S.A.": "United States",
    "UK": "United Kingdom",
    "U.K.": "United Kingdom",
    "UAE": "United Arab Emirates",
    "Korea": "South Korea",
    "Republic of Korea": "South Korea",
    "Viet Nam": "Vietnam",
    "Russian Federation": "Russia",
    "Türkiye": "Turkey",
}

REGION_BY_COUNTRY = {
    "United States": "North America",
    "Canada": "North America",
    "Mexico": "North America",
    "Argentina": "South America",
    "Bolivia": "South America",
    "Brazil": "South America",
    "Chile": "South America",
    "Colombia": "South America",
    "Costa Rica": "South America",
    "Dominican Republic": "South America",
    "Ecuador": "South America",
    "Jamaica": "South America",
    "Panama": "South America",
    "Paraguay": "South America",
    "Peru": "South America",
    "Trinidad and Tobago": "South America",
    "Uruguay": "South America",
    "Venezuela": "South America",
    "Austria": "Europe",
    "Belgium": "Europe",
    "Bulgaria": "Europe",
    "Croatia": "Europe",
    "Cyprus": "Europe",
    "Czech Republic": "Europe",
    "Denmark": "Europe",
    "Estonia": "Europe",
    "Finland": "Europe",
    "France": "Europe",
    "Germany": "Europe",
    "Greece": "Europe",
    "Hungary": "Europe",
    "Iceland": "Europe",
    "Ireland": "Europe",
    "Italy": "Europe",
    "Latvia": "Europe",
    "Lithuania": "Europe",
    "Luxembourg": "Europe",
    "Malta": "Europe",
    "Netherlands": "Europe",
    "Norway": "Europe",
    "Poland": "Europe",
    "Portugal": "Europe",
    "Romania": "Europe",
    "Russia": "Europe",
    "Serbia": "Europe",
    "Slovakia": "Europe",
    "Slovenia": "Europe",
    "Spain": "Europe",
    "Sweden": "Europe",
    "Switzerland": "Europe",
    "Turkey": "Europe",
    "Ukraine": "Europe",
    "United Kingdom": "Europe",
    "Algeria": "Africa",
    "Botswana": "Africa",
    "Egypt": "Africa",
    "Ghana": "Africa",
    "Ivory Coast": "Africa",
    "Kenya": "Africa",
    "Mauritius": "Africa",
    "Morocco": "Africa",
    "Namibia": "Africa",
    "Nigeria": "Africa",
    "Rwanda": "Africa",
    "South Africa": "Africa",
    "Tunisia": "Africa",
    "Uganda": "Africa",
    "Zambia": "Africa",
    "Zimbabwe": "Africa",
    "Bangladesh": "Asia",
    "Cambodia": "Asia",
    "China": "Asia",
    "Hong Kong": "Asia",
    "India": "Asia",
    "Indonesia": "Asia",
    "Japan": "Asia",
    "Kazakhstan": "Asia",
    "Laos": "Asia",
    "Macau": "Asia",
    "Malaysia": "Asia",
    "Mongolia": "Asia",
    "Pakistan": "Asia",
    "Philippines": "Asia",
    "Singapore": "Asia",
    "South Korea": "Asia",
    "Sri Lanka": "Asia",
    "Taiwan": "Asia",
    "Thailand": "Asia",
    "Vietnam": "Asia",
    "Bahrain": "Middle East",
    "Iran": "Middle East",
    "Iraq": "Middle East",
    "Israel": "Middle East",
    "Jordan": "Middle East",
    "Kuwait": "Middle East",
    "Lebanon": "Middle East",
    "Oman": "Middle East",
    "Qatar": "Middle East",
    "Saudi Arabia": "Middle East",
    "United Arab Emirates": "Middle East",
    "Australia": "Oceania",
    "New Zealand": "Oceania",
    "Bermuda": "Global",
    "Cayman Islands": "Global",
    "Guernsey": "Global",
    "Isle of Man": "Global",
    "Jersey": "Global",
    "Liechtenstein": "Global",
}

ASSET_LOADERS = [
    ("equities", fd.Equities),
    ("etfs", fd.ETFs),
    ("funds", fd.Funds),
    ("indices", fd.Indices),
    ("currencies", fd.Currencies),
    ("cryptos", fd.Cryptos),
    ("moneymarkets", fd.Moneymarkets),
]


def canonicalize_text(value: Any) -> Any:
    if pd.isna(value):
        return pd.NA
    text = str(value).strip()
    if not text:
        return pd.NA
    return re.sub(r"\s+", " ", text)


def normalize_country(value: Any) -> Any:
    normalized = canonicalize_text(value)
    if pd.isna(normalized):
        return pd.NA
    return COUNTRY_ALIASES.get(str(normalized), normalized)


def normalize_bool(value: Any, default: bool = True) -> bool:
    if isinstance(value, bool):
        return value
    if pd.isna(value):
        return default
    text = str(value).strip().lower()
    if text in {"false", "0", "no", "n", "inactive", "delisted"}:
        return False
    if text in {"true", "1", "yes", "y", "active", "listed"}:
        return True
    return default


def first_existing_column(df: pd.DataFrame, candidates: list[str]) -> str | None:
    lowered = {str(column).strip().lower(): column for column in df.columns}
    for candidate in candidates:
        column = lowered.get(candidate.lower())
        if column is not None:
            return column
    return None


def pick_series(df: pd.DataFrame, candidates: list[str], default: Any = pd.NA) -> pd.Series:
    column = first_existing_column(df, candidates)
    if column is None:
        return pd.Series([default] * len(df), index=df.index, dtype="object")
    return df[column]


def standardize_symbol_column(df: pd.DataFrame) -> pd.DataFrame:
    output = df.copy()

    if isinstance(output.index, pd.MultiIndex):
        output = output.reset_index()
    elif output.index.name and str(output.index.name).strip().lower() in {"symbol", "ticker", "code"}:
        output = output.reset_index()

    lowered = [str(column).strip().lower() for column in output.columns]
    if "symbol" not in lowered:
        for candidate in ["symbol", "ticker", "code"]:
            column = first_existing_column(output, [candidate])
            if column is not None:
                output["symbol"] = output[column]
                break

    return output


def region_for_country(country: Any) -> str:
    if pd.isna(country):
        return "Unknown"
    return REGION_BY_COUNTRY.get(str(country), "Unknown")


def normalize_market(asset_type: str, market: Any, exchange: Any) -> str:
    normalized_market = canonicalize_text(market)
    normalized_exchange = canonicalize_text(exchange)

    if asset_type == "currencies":
        return "FX"
    if asset_type == "cryptos":
        return "CRYPTO"
    if asset_type == "moneymarkets":
        return "BOND"
    if not pd.isna(normalized_market):
        return str(normalized_market).upper()
    if not pd.isna(normalized_exchange):
        return str(normalized_exchange).upper()
    if asset_type == "indices":
        return "GLOBAL"
    return "UNKNOWN"


def clean_frame(df: pd.DataFrame, asset_type: str) -> pd.DataFrame:
    normalized = standardize_symbol_column(df).copy()

    symbol = pick_series(normalized, ["symbol", "ticker", "code"])
    name = pick_series(normalized, ["name", "company_name", "short_name", "long_name", "description", "summary"])
    country = pick_series(normalized, ["country"])
    exchange = pick_series(normalized, ["exchange", "exchange_name"])
    market = pick_series(normalized, ["market", "category", "family"])
    currency = pick_series(normalized, ["currency"])
    isin = pick_series(normalized, ["isin"])
    is_active = pick_series(normalized, ["is_active", "active", "listed", "delisted"], default=True)

    output = pd.DataFrame(
        {
            "symbol": symbol,
            "name": name,
            "asset_type": asset_type,
            "country": country,
            "exchange": exchange,
            "market": market,
            "currency": currency,
            "isin": isin,
            "provider": "financedatabase",
            "is_active": is_active,
        }
    )

    output["symbol"] = output["symbol"].apply(canonicalize_text)
    output["name"] = output["name"].apply(canonicalize_text)
    output["country"] = output["country"].apply(normalize_country)
    output["exchange"] = output["exchange"].apply(canonicalize_text)
    output["currency"] = output["currency"].apply(canonicalize_text)
    output["isin"] = output["isin"].apply(canonicalize_text)
    output["is_active"] = output["is_active"].apply(normalize_bool)
    output["region"] = output["country"].apply(region_for_country)
    output["market"] = [
        normalize_market(asset_type, row_market, row_exchange)
        for row_market, row_exchange in zip(output["market"], output["exchange"])
    ]

    output = output[OUTPUT_COLUMNS]
    output = output[~output["symbol"].isna()].copy()
    output = output.dropna(subset=["symbol"])
    output["symbol"] = output["symbol"].astype("string").str.strip()
    output = output[output["symbol"] != ""].copy()

    for column in OUTPUT_COLUMNS:
        if column == "is_active":
            output[column] = output[column].astype(bool)
        else:
            output[column] = output[column].astype("string")

    return output


def deduplicate(df: pd.DataFrame) -> pd.DataFrame:
    working = df.copy()
    working["_completeness"] = (
        working[["name", "country", "region", "exchange", "market", "currency", "isin"]]
        .replace({"": pd.NA})
        .notna()
        .sum(axis=1)
    )

    dedupe_keys = ["symbol", "asset_type", "exchange", "market", "country", "currency"]
    working = working.sort_values(
        by=dedupe_keys + ["_completeness"],
        ascending=[True, True, True, True, True, True, False],
        na_position="last",
    )
    working = working.drop_duplicates(subset=dedupe_keys, keep="first")
    working = working.drop(columns="_completeness")
    working = working.sort_values(
        by=["asset_type", "region", "country", "exchange", "symbol"],
        na_position="last",
    ).reset_index(drop=True)
    return working


def load_asset_frame(asset_type: str, loader: Any) -> pd.DataFrame:
    try:
        source = loader()
        raw = source.select() if hasattr(source, "select") else source
        if not isinstance(raw, pd.DataFrame):
            raw = pd.DataFrame(raw)
        return clean_frame(raw, asset_type=asset_type)
    except Exception as exc:
        print(f"[WARN] Failed to load {asset_type}: {exc}")
        return pd.DataFrame(columns=OUTPUT_COLUMNS)


def count_series(series: pd.Series) -> dict[str, int]:
    counts = (
        series.fillna("Unknown")
        .replace({"": "Unknown"})
        .value_counts(dropna=False)
        .sort_index()
    )
    return {str(key): int(value) for key, value in counts.items()}


def build_summary(df: pd.DataFrame) -> dict[str, Any]:
    return {
        "provider": "financedatabase",
        "rows_total": int(len(df)),
        "columns": OUTPUT_COLUMNS,
        "asset_type_counts": count_series(df["asset_type"]),
        "region_counts": count_series(df["region"]),
        "country_counts": count_series(df["country"]),
    }


def main() -> None:
    frames: list[pd.DataFrame] = []

    for asset_type, loader in ASSET_LOADERS:
        frame = load_asset_frame(asset_type, loader)
        if frame.empty:
            print(f"[WARN] No rows loaded for {asset_type}")
            continue

        frames.append(frame)
        print(f"[OK] Loaded {asset_type}: {len(frame):,} rows")

    if not frames:
        raise RuntimeError("No FinanceDatabase asset classes were loaded successfully.")

    universe = pd.concat(frames, ignore_index=True)
    universe = deduplicate(universe)

    universe.to_parquet(PARQUET_PATH, index=False)
    universe.to_csv(CSV_PATH, index=False)

    summary = build_summary(universe)
    SUMMARY_PATH.write_text(json.dumps(summary, indent=2), encoding="utf-8")

    print("\nCreated files:")
    print(f"- {PARQUET_PATH}")
    print(f"- {CSV_PATH}")
    print(f"- {SUMMARY_PATH}")

    print("\nSummary:")
    print(f"- Total rows: {len(universe):,}")
    print("- By asset type:")
    for key, value in summary["asset_type_counts"].items():
        print(f"  - {key}: {value:,}")
    print("- By region:")
    for key, value in summary["region_counts"].items():
        print(f"  - {key}: {value:,}")


if __name__ == "__main__":
    main()
