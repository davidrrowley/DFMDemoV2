# Holdings*Price Validation Report: Deployment Checklist

## 📋 Overview
This Power BI report enables human-in-the-loop validation of the holdings * bid price reconciliation check, ensuring data quality before Stage 3 processing.

**Metric**: Reconciliation % = `(holding × local_bid_price) / ROUND(holding × local_bid_price, 2) × 100`  
**Expected Range**: 98-102% (accounts for decimal rounding)

---

## ✅ Quick Setup (4 Steps)

### Step 1: Create SQL View in Fabric (5 minutes)
**Location**: Fabric Workspace → Your Lakehouse → SQL Notebook

1. Create new SQL cell
2. Copy & paste entire contents from: `infra/fabric/sql/setup_reconciliation_validation.sql`
3. Run the cell (all 7 queries)
4. **Verify**: You should see summary statistics showing total records and reconciliation %. Example output:
   ```
   total_records: 16320
   records_in_range: 15800
   outlier_records: 520
   pct_in_range: 96.8%
   ```

### Step 2: Open Power BI Report
**File**: `infra/fabric/reports/holdings_price_validator.pbix`

1. Open Power BI Desktop
2. File → Open → Select `holdings_price_validator.pbix`
3. You'll get a prompt about data sources

### Step 3: Configure Fabric SQL Connection
**In Power BI Desktop**:

1. Click "Edit Queries" when prompted
2. In Power Query Editor:
   - Right-click on the connection
   - Select "Edit Query"
   - Update server and database details:
     - **Server**: `your-workspace-id.analysis.windows.net`
     - **Database**: Your default lakehouse database
3. Click "Refresh" to load data from the view
4. Should load ~16K records with reconciliation metrics

### Step 4: Publish to Fabric Workspace
**In Power BI Desktop**:

1. File → Publish
2. Select your Fabric Workspace
3. Choose "Replace" if file already exists
4. Share report URL with validation team

---

## 📊 Report Pages & Features

### Page 1: Summary Dashboard
- **KPI Cards**: Total records, in-range %, outlier count
- **Histogram**: Reconciliation % distribution (color-coded)
- **Top Outliers Table**: 20 records with highest variance (sortable)

**Use this to**: Get executive summary of data quality

### Page 2: Outlier Analysis & Remediation
- **Filters**: Reconciliation Status, Currency, Include/Exclude
- **Detailed Table**: All outlier records with full context
- **Variance Chart**: By currency showing breakdown
- **Export**: Right-click table → Export to CSV for remediation team

**Use this to**: Drill into specific problem records for investigation

### Page 3: Data Quality Assessment
- **Completeness Scorecards**: % of non-null holdings & prices
- **Currency Distribution**: Pie chart of records by currency
- **Include/Exclude Split**: Donut chart showing include vs. exclude counts
- **Status by Currency**: Stacked bar showing reconciliation status distribution

**Use this to**: Understand data quality patterns by dimension

---

## 🔍 Expected Findings

### Reconciliation Status Categories

| Status | Meaning | Action |
|--------|---------|--------|
| **IN_RANGE** (98-102%) | ✅ Data is clean | No action needed |
| **BELOW_RANGE** (<98%) | ⚠️ Holdings or price may be understated | Review source data |
| **ABOVE_RANGE** (>102%) | ⚠️ Holdings or price may be overstated | Review source data |
| **MISSING_DATA** | ❌ NULL holdings or price | Check source completeness |
| **ZERO_VALUE** | ❌ Zero calculation result | Investigate edge case |

### Common Root Causes

**High Variance Issues**:
- Data entry errors in source Excel files
- Currency conversion issues
- Decimal vs. integer confusion (e.g., 1000 vs. 10.00)
- FX rate misalignment

**Missing Data**:
- Blank cells in source files
- Import failures
- Null handling in Stage 1 ingestion

---

## 🔧 Troubleshooting

### Problem: "Column not found" error when opening .pbix
**Solution**: The schema names changed. View was created correctly, but Power BI still references old column names. 
1. In Power BI, go to Transform Data
2. Update query to reference `vw_holdings_price_validation`
3. Verify columns match: `holding`, `local_bid_price`, `bid_value_local`, `reconciliation_pct`, etc.

### Problem: No data appears in report
**Solution**: Likely a SQL connection issue
1. Check Fabric SQL endpoint is accessible from your network
2. Verify you have read permissions on the lakehouse
3. Run test query in Fabric SQL notebook to confirm `individual_dfm_consolidated` has data
4. In Power BI, go to File → Options → Data Privacy → Set to "Ignore Privacy Levels"

### Problem: Reconciliation % values look wrong
**Solution**: Check if rounding is being applied correctly
1. Run query: `SELECT TOP 5 holding, local_bid_price, reconciliation_pct, variance_from_100_pct FROM vw_holdings_price_validation WHERE reconciliation_status != 'IN_RANGE'`
2. Manually verify: `(holding × local_bid_price) / ROUND(holding × local_bid_price, 2) × 100`
3. If manual calc differs, SQL view may need adjustment

---

## 📋 Workflow Integration

### Before Stage 3 Execution

```
SQL View Created
    ↓
Power BI Report Published
    ↓
Business Validation Review
    │
    ├─→ Data looks good → Proceed to Stage 3 ✅
    │
    └─→ Outliers found → Remediation Loop:
            ├─ Export outliers as CSV from Power BI
            ├─ Send to data team for investigation
            ├─ Update source data in Excel/system
            ├─ Clear Stage 2 & 3 tables
            ├─ Re-run Stage 2 notebook
            ├─ Validate again in Power BI
            └─ Once 95%+ in range → Proceed to Stage 3
```

---

## 📞 Questions for Validation Team

When reviewing the Power BI report, ask:

1. **Are the outliers legitimate?**
   - Some variance may be by design (e.g., accrued interest adjustments)
   - Are specific securities always problematic?

2. **What tolerance should we accept?**
   - Current threshold: 98-102%
   - Should it be stricter (e.g., 99-101%) or looser (e.g., 95-105%)?

3. **Are there patterns?**
   - Specific currencies with issues?
   - Include vs. Exclude split?
   - Particular account numbers?

4. **Data Quality Root Cause**
   - Which column likely has errors?
   - Can it be fixed in source system or requires manual remediation?

---

## ✨ Next Steps

- [ ] Run SQL view creation in Fabric (Step 1)
- [ ] Open Power BI report file (Step 2)
- [ ] Configure SQL connection in Power BI (Step 3)
- [ ] Publish to Fabric Workspace (Step 4)
- [ ] Share report URL with validation team
- [ ] Collect feedback on outliers found
- [ ] Plan remediation or proceed to Stage 3

---

## 📁 Files Reference

| File | Purpose |
|------|---------|
| `infra/fabric/sql/vw_holdings_price_validation.sql` | View definition (already created) |
| `infra/fabric/sql/setup_reconciliation_validation.sql` | Complete SQL setup with 7 validation queries |
| `infra/fabric/reports/holdings_price_validator.pbix` | Power BI report file (ready to open) |
| `scripts/generate_powerbi_report.py` | Report generator (for future regeneration) |

---

**Status**: ✅ Ready for deployment  
**Last Updated**: 2026-03-04  
**Created for**: Holdings*Price Validation (Human-in-Loop Data QA)
