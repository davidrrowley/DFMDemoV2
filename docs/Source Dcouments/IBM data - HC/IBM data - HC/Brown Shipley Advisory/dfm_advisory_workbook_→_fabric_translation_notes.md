# Brown Shipley Advisory Template — Workbook Logic Documentation

This document describes the structure and behaviour of the **Brown Shipley Advisory Template** workbook and translates its operational logic into a form suitable for implementation in Microsoft Fabric.

The workbook implements a deterministic transformation pipeline that converts raw DFM extracts into a standardised TPIR output.

The purpose of this document is to make the logic explicit so it can be reproduced programmatically.

---

# Workbook Overview

The workbook follows a consistent staged pattern.

Raw data is pasted into two sheets.

- **Original Data – Cash**
- **Original Data – Non Cash**

These are transformed through formula‑driven sheets.

- **Edited – Cash**
- **Edited – Non Cash**

Rows classified as **Include** are consolidated into:

- **tpir_load**

Supporting control datasets:

- **Mappings** – policy and security mappings
- **IH Report** – authoritative policy inclusion list
- **Check** – FX rates and validation checks

---

# Logical Processing Flow

Each position row moves through four logical stages.

1. Identifier mapping
2. Include / Remove classification
3. Numeric derivations
4. Projection into TPIR format

---

# Mappings Sheet

This sheet contains **DFM‑specific mapping data**.

Two logical mapping groups exist in the same sheet.

• Policy mapping
• Security mapping

## Column Inventory

| Column | Name | Type | Example | Notes |
|------|------|------|------|------|
| A | UBS Ref | Text | ID‑B0643545 | Raw policy reference from source data |
| B | SL PolNo | Text | ID‑087CFAFE | Standardised policy identifier |
| D | ISIN+CCY | Text | GB0004893086‑GBP | Composite security lookup key |
| E | final_security_code | Text | 0489308 | Security code returned to Edited sheet |
| F | unique_security_code | Text | 0489308 | Often same as column E |
| G | isin | Text | GB0004893086 | Returned into Edited sheet |
| H | currency | Text | GBP | Currency component |
| I | sedol | Text | 0489308 | Returned as Other_Security_ID |
| J | SECURITY_NAME | Text | Asset name | Used as asset description |

## Join Logic

### Policy mapping

Join condition

```
Original Client ID = Mappings.UBS Ref
```

Output

```
Policyholder_Number = Mappings.SL PolNo
```

Fallback behaviour

If Client ID blank → Excel outputs literal `REMOVE`.

---

### Security mapping

Composite key constructed in Edited sheet:

```
identifier = IF(ISIN blank, SEDOL, ISIN)
lookup_key = identifier + "-" + currency
```

Example

```
GB0004893086-GBP
0489308-GBP
```

Join condition

```
lookup_key = Mappings.ISIN+CCY
```

Output

```
Security_Code = final_security_code
```

---

# IH Report

This sheet controls policy inclusion and movement validation.

## Column Inventory

| Column | Name | Type | Example | Notes |
|------|------|------|------|------|
| A | Policy number | Text | ID‑087CFAFE | Primary join key |
| B | Valuation | Number | 930745.87 | Used for movement checks |
| C | Included? | Text | Included in confirm | Derived formula |
| D | Cash | Number | calculated | Confirm cash total |
| E | Stock | Number | calculated | Confirm stock total |
| F | Confirm value | Number | calculated | Cash + stock |
| G | Movt | Number | calculated | Movement ratio |
| H | Status | Text | Exclude | Used by include/remove rule |

## Join Logic

```
edited.Policyholder_Number = ih.Policy number
```

If policy appears in IH with status **Exclude**, the row is removed.

---

# Check Sheet

This sheet contains validations and an embedded FX lookup table.

## FX Table Structure

| Currency | Rate |
|------|------|
| EUR | 0.872676 |
| USD | 0.742170 |

Lookup formula

```
VLOOKUP(currency, Check!A:B,2,0)
```

Fabric equivalent

```
fx_rates(currency, rate_to_gbp, period)
```

---

# Original Data – Cash

Raw pasted dataset for cash balances.

## Key Columns

| Column | Name | Type | Notes |
|------|------|------|------|
| A | Client ID | Text | Policy mapping key |
| E | Balance at Value Date | Text/Number | European decimal format |
| N | Account currency | Text | Used for FX lookup |

## Transformation Rules

European decimal parsing

```
1.234,56 → 1234.56
```

Conversion

```
Cash_Value_GBP = parsed_value * FX(currency)
```

---

# Edited – Cash

Working transformation layer for cash.

## Column Inventory

| Column | Name | Notes |
|------|------|------|
| A | Include? | Decision tree output |
| D | Policyholder_Number | Mapping result |
| E | Security_Code | "TPY_CASH_" + currency |
| I | Asset_Name | Constant "CASH" |
| K | Cash_Value_in_GBP | Parsed + FX converted |
| N | Holding | Equals K |
| O | Loc_Bid_Price | Constant 1 |
| P | Currency_Local | From original data |

---

# Include / Remove Decision Tree

This rule is applied identically to cash and non‑cash rows.

Exact Excel order:

```
IF policy exists in IH with status = "Exclude"
    → "Remove - unreliable values"

ELSE IF policy blank OR policy="REMOVE*" OR value=0
    → "Remove"

ELSE IF policy exists in IH
    → "Include"

ELSE
    → "Remove"
```

Definitions

Blank = empty string

Zero = numeric 0 after parsing

REMOVE* = sentinel value generated by mapping logic

---

# Original Data – Non Cash

Raw pasted security positions.

## Key Columns

| Column | Name | Notes |
|------|------|------|
| A | Client ID | Policy mapping key |
| D | Balance at Value Date | Parsed into holding |
| I | Cash Evaluation | Parsed into GBP value |
| J | Currency | Used for FX and composite key |
| N | ISIN Code | Primary identifier |
| P | Sedol Code | Fallback identifier |

---

# Edited – Non Cash

Transformation layer for securities.

## Core Columns

| Column | Name | Notes |
|------|------|------|
| A | Include? | Decision tree |
| D | Policyholder_Number | From mapping |
| E | Security_Code | From composite key mapping |
| F | ISIN | Returned from mapping row |
| G | Other_Security_ID | SEDOL from mapping row |
| I | Asset_Name | Security description |
| L | Bid_Value_in_GBP | Parsed + FX conversion |
| N | Holding | Parsed balance |
| O | Loc_Bid_Price | Derived price |
| P | Currency_Local | Source currency |

---

# Calculated Fields

## Bid_Value_in_GBP

```
parsed_value = parse_european_decimal(Cash Evaluation)
Bid_Value_GBP = parsed_value * FX(currency)
```

## Holding

```
Holding = parse_european_decimal(Balance at Value Date)
```

## Loc_Bid_Price

```
price = (Bid_Value_GBP / Holding) / FX(currency)
```

---

# TPIR Load

Final output table created by concatenating **Include rows** from both Edited sheets.

## Schema

| Column | Name |
|------|------|
| A | Policyholder_Number |
| B | Security_Code |
| C | ISIN |
| D | Other_Security_ID |
| E | ID_Type |
| F | Asset_Name |
| G | Acq_Cost_in_GBP |
| H | Cash_Value_in_GBP |
| I | Bid_Value_in_GBP |
| J | Accrued_Interest |
| K | Holding |
| L | Loc_Bid_Price |
| M | Currency_Local |

---

# Example Rows

## Happy Path (Include)

```
Client ID = ID-B0643545
Mapping → Policy ID-087CFAFE
IH Report contains policy
Security mapping exists
Holding > 0
Bid value > 0

Result → Include
```

---

## Sad Path (Remove)

Case 1: policy missing in IH

```
Policy mapped but not present in IH

Result → Remove
```

Case 2: zero value

```
Bid_Value_in_GBP = 0

Result → Remove
```

---

# Fabric Architecture Equivalent

## Bronze

Raw datasets

```
raw_cash
raw_non_cash
```

## Silver

Transformation layer

```
edited_cash
edited_non_cash
```

## Gold

Final output

```
tpir_load
```

---

# Key Insight

The entire workbook is driven by three reference datasets.

```
Mappings
IH Report
FX Rates
```

Once these are modelled as tables in Fabric, the remainder of the spreadsheet logic becomes straightforward deterministic transformations.

---

# Next Step

Construct the **Edited sheet column‑level data model** describing:

• source fields

• transformation logic

• dependencies

• null handling

• validation rules

This becomes the contract for the Fabric Silver layer.

