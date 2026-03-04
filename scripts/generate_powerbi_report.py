"""
Generate Power BI Report: Holdings*Price Reconciliation Validator
Programmatically creates a .pbix file with data connections, measures, and visualizations.

Usage:
    python generate_powerbi_report.py \
        --workspace-id "your-workspace-id" \
        --database-server "your-server.analysis.windows.net" \
        --database-name "default" \
        --output-path "./reports/holdings_price_validator.pbix"
"""

import json
import zipfile
import argparse
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Any
import uuid


class PowerBIReportGenerator:
    """Generate Power BI reports programmatically."""
    
    def __init__(self, output_path: str):
        """Initialize report generator."""
        self.output_path = Path(output_path)
        self.output_path.parent.mkdir(parents=True, exist_ok=True)
        self.report_id = str(uuid.uuid4())
        self.dataset_id = str(uuid.uuid4())
        
    def create_report(self, 
                     workspace_id: str,
                     database_server: str, 
                     database_name: str):
        """Create complete Power BI report with all pages and visualizations."""
        
        print(f"[INFO] Generating Power BI report: {self.output_path}")
        
        # Create report structure
        report_json = self._build_report_json(workspace_id, database_server, database_name)
        
        # Build .pbix file (ZIP format)
        with zipfile.ZipFile(self.output_path, 'w', zipfile.ZIP_DEFLATED) as pbix:
            pbix.writestr('Report/Layout', json.dumps(report_json, indent=2))
            pbix.writestr('Report/StaticResources/SharedResources/BaseThemes/CY19SU04.json', 
                         self._get_default_theme())
            pbix.writestr('Metadata', self._build_metadata_json())
            pbix.writestr('Version', '2.0')
        
        print(f"[SUCCESS] Report created: {self.output_path}")
        return self.output_path
    
    def _build_report_json(self, workspace_id: str, database_server: str, database_name: str) -> Dict:
        """Build report JSON structure."""
        return {
            "name": "Holdings*Price Reconciliation Validator",
            "displayLanguage": "en-US",
            "version": "1.0.0",
            "pages": [
                self._build_summary_page(),
                self._build_outliers_page(),
                self._build_data_quality_page()
            ],
            "dataSources": [
                self._build_data_source(database_server, database_name)
            ],
            "measures": self._build_measures()
        }
    
    def _build_summary_page(self) -> Dict:
        """Build Summary Dashboard page."""
        return {
            "name": "Summary Dashboard",
            "displayName": "Summary Dashboard",
            "height": 720,
            "width": 1280,
            "visualizations": [
                {
                    "name": "TitleTextbox",
                    "type": "textbox",
                    "x": 20,
                    "y": 10,
                    "width": 400,
                    "height": 40,
                    "properties": {
                        "text": "Holdings * Price Reconciliation Check",
                        "fontSize": 24,
                        "fontWeight": "bold"
                    }
                },
                {
                    "name": "KPI_TotalRecords",
                    "type": "kpi",
                    "x": 20,
                    "y": 60,
                    "width": 200,
                    "height": 120,
                    "properties": {
                        "title": "Total Records",
                        "measure": "[Total Records]",
                        "fontSize": 28
                    }
                },
                {
                    "name": "KPI_InRange",
                    "type": "kpi",
                    "x": 240,
                    "y": 60,
                    "width": 200,
                    "height": 120,
                    "properties": {
                        "title": "Records In Range (98-102%)",
                        "measure": "[Records In Range]",
                        "fontSize": 20,
                        "color": "#70AD47"
                    }
                },
                {
                    "name": "KPI_OutlierCount",
                    "type": "kpi",
                    "x": 460,
                    "y": 60,
                    "width": 200,
                    "height": 120,
                    "properties": {
                        "title": "Outlier Count",
                        "measure": "[Outlier Count]",
                        "fontSize": 20,
                        "color": "#C55A11"
                    }
                },
                {
                    "name": "KPI_OutlierPct",
                    "type": "kpi",
                    "x": 680,
                    "y": 60,
                    "width": 200,
                    "height": 120,
                    "properties": {
                        "title": "Outlier %",
                        "measure": "[Outlier %]",
                        "format": "0.0%",
                        "fontSize": 20,
                        "color": "#ED7D31"
                    }
                },
                {
                    "name": "Distribution_Histogram",
                    "type": "columnChart",
                    "x": 20,
                    "y": 200,
                    "width": 600,
                    "height": 300,
                    "properties": {
                        "title": "Reconciliation % Distribution",
                        "xAxis": "reconciliation_pct_binned",
                        "yAxis": "Count of Records",
                        "legend": "reconciliation_status",
                        "colors": {
                            "IN_RANGE": "#70AD47",
                            "BELOW_RANGE": "#C5504E",
                            "ABOVE_RANGE": "#F79646",
                            "MISSING_DATA": "#B4B4B4"
                        }
                    }
                },
                {
                    "name": "TopOutliers_Table",
                    "type": "table",
                    "x": 640,
                    "y": 200,
                    "width": 600,
                    "height": 300,
                    "properties": {
                        "title": "Top 20 Outliers (by absolute variance)",
                        "columns": [
                            "security_code",
                            "holding",
                            "local_bid_price",
                            "bid_value_local",
                            "reconciliation_pct",
                            "variance_from_100_pct"
                        ],
                        "sortBy": "variance_from_100_pct",
                        "sortOrder": "descending"
                    }
                }
            ]
        }
    
    def _build_outliers_page(self) -> Dict:
        """Build Outlier Analysis & Remediation page."""
        return {
            "name": "Outlier Analysis",
            "displayName": "Outlier Analysis & Remediation",
            "height": 720,
            "width": 1280,
            "visualizations": [
                {
                    "name": "FilterPane",
                    "type": "slicer",
                    "x": 20,
                    "y": 10,
                    "width": 250,
                    "height": 250,
                    "properties": {
                        "column": "reconciliation_status",
                        "title": "Reconciliation Status",
                        "type": "list"
                    }
                },
                {
                    "name": "FilterPane_Currency",
                    "type": "slicer",
                    "x": 290,
                    "y": 10,
                    "width": 200,
                    "height": 250,
                    "properties": {
                        "column": "currency_code",
                        "title": "Currency",
                        "type": "list"
                    }
                },
                {
                    "name": "FilterPane_IncludeFlag",
                    "type": "slicer",
                    "x": 510,
                    "y": 10,
                    "width": 200,
                    "height": 250,
                    "properties": {
                        "column": "include_flag",
                        "title": "Include/Exclude",
                        "type": "list"
                    }
                },
                {
                    "name": "OutlierTable",
                    "type": "table",
                    "x": 20,
                    "y": 280,
                    "width": 1240,
                    "height": 400,
                    "properties": {
                        "title": "Detailed Outlier Records (Filtered)",
                        "columns": [
                            "policyholder_number",
                            "security_code",
                            "asset_name",
                            "holding",
                            "local_bid_price",
                            "bid_value_local",
                            "reconciliation_pct",
                            "variance_from_100_pct",
                            "include_flag",
                            "currency_code"
                        ],
                        "conditionalFormatting": {
                            "column": "variance_from_100_pct",
                            "rules": [
                                {"range": [-100, -2], "color": "#C5504E"},
                                {"range": [-2, -1], "color": "#F79646"},
                                {"range": [1, 2], "color": "#F79646"},
                                {"range": [2, 100], "color": "#C5504E"}
                            ]
                        }
                    }
                },
                {
                    "name": "VarianceByCountry_Chart",
                    "type": "columnChart",
                    "x": 20,
                    "y": 60,
                    "width": 760,
                    "height": 200,
                    "properties": {
                        "title": "Variance Distribution by Currency",
                        "xAxis": "currency_code",
                        "yAxis": "Count of Records",
                        "secondaryYAxis": "Avg(variance_from_100_pct)",
                        "legend": "reconciliation_status"
                    }
                }
            ]
        }
    
    def _build_data_quality_page(self) -> Dict:
        """Build Data Quality Assessment page."""
        return {
            "name": "Data Quality",
            "displayName": "Data Quality Assessment",
            "height": 720,
            "width": 1280,
            "visualizations": [
                {
                    "name": "Title",
                    "type": "textbox",
                    "x": 20,
                    "y": 10,
                    "width": 400,
                    "height": 30,
                    "properties": {
                        "text": "Data Quality & Completeness Analysis",
                        "fontSize": 20,
                        "fontWeight": "bold"
                    }
                },
                {
                    "name": "Scorecard_HoldingsNonNull",
                    "type": "kpi",
                    "x": 20,
                    "y": 50,
                    "width": 150,
                    "height": 100,
                    "properties": {
                        "title": "Non-null Holdings %",
                        "measure": "[Holdings Completeness %]",
                        "format": "0.0%",
                        "fontSize": 18
                    }
                },
                {
                    "name": "Scorecard_PriceNonNull",
                    "type": "kpi",
                    "x": 190,
                    "y": 50,
                    "width": 150,
                    "height": 100,
                    "properties": {
                        "title": "Non-null Bid Price %",
                        "measure": "[Price Completeness %]",
                        "format": "0.0%",
                        "fontSize": 18
                    }
                },
                {
                    "name": "Scorecard_BidValueNonNull",
                    "type": "kpi",
                    "x": 360,
                    "y": 50,
                    "width": 150,
                    "height": 100,
                    "properties": {
                        "title": "Non-null Bid Value %",
                        "measure": "[Bid Value Completeness %]",
                        "format": "0.0%",
                        "fontSize": 18
                    }
                },
                {
                    "name": "CurrencyDistribution",
                    "type": "pieChart",
                    "x": 20,
                    "y": 170,
                    "width": 350,
                    "height": 300,
                    "properties": {
                        "title": "Currency Distribution",
                        "values": "currency_code",
                        "size": "Count of Records"
                    }
                },
                {
                    "name": "IncludeExcludeDistribution",
                    "type": "donutChart",
                    "x": 390,
                    "y": 170,
                    "width": 350,
                    "height": 300,
                    "properties": {
                        "title": "Include/Exclude Distribution",
                        "values": "include_flag",
                        "size": "Count of Records"
                    }
                },
                {
                    "name": "ReconciliationByType",
                    "type": "stackedColumnChart",
                    "x": 760,
                    "y": 170,
                    "width": 500,
                    "height": 300,
                    "properties": {
                        "title": "Reconciliation Status Distribution",
                        "xAxis": "currency_code",
                        "yAxis": "Count of Records",
                        "stackBy": "reconciliation_status",
                        "colors": {
                            "IN_RANGE": "#70AD47",
                            "BELOW_RANGE": "#C5504E",
                            "ABOVE_RANGE": "#F79646",
                            "MISSING_DATA": "#B4B4B4"
                        }
                    }
                }
            ]
        }
    
    def _build_data_source(self, database_server: str, database_name: str) -> Dict:
        """Build data source configuration."""
        return {
            "name": "Fabric_SQL",
            "connectionString": f"Provider=MSOLAP;Integrated Security=ClaimsToken;Persist Encrypted Token=true;Initial Catalog={database_name};Data Source={database_server}",
            "type": "SQL",
            "queries": [
                {
                    "name": "vw_holdings_price_validation",
                    "expression": "SELECT * FROM vw_holdings_price_validation"
                }
            ]
        }
    
    def _build_measures(self) -> List[Dict]:
        """Build DAX measures."""
        return [
            {
                "name": "Total Records",
                "expression": "COUNTROWS('vw_holdings_price_validation')"
            },
            {
                "name": "Records In Range",
                "expression": "CALCULATE(COUNTROWS('vw_holdings_price_validation'), 'vw_holdings_price_validation'[reconciliation_status] = \"IN_RANGE\")"
            },
            {
                "name": "Outlier Count",
                "expression": "CALCULATE(COUNTROWS('vw_holdings_price_validation'), 'vw_holdings_price_validation'[reconciliation_status] <> \"IN_RANGE\")"
            },
            {
                "name": "Outlier %",
                "expression": "DIVIDE([Outlier Count], [Total Records], 0)"
            },
            {
                "name": "Avg Reconciliation %",
                "expression": "AVERAGE('vw_holdings_price_validation'[reconciliation_pct])"
            },
            {
                "name": "Max Variance",
                "expression": "MAXX('vw_holdings_price_validation', ABS('vw_holdings_price_validation'[variance_from_100_pct]))"
            },
            {
                "name": "Holdings Completeness %",
                "expression": "DIVIDE(COUNTROWS('vw_holdings_price_validation') - SUM('vw_holdings_price_validation'[is_holding_null]), COUNTROWS('vw_holdings_price_validation'))"
            },
            {
                "name": "Price Completeness %",
                "expression": "DIVIDE(COUNTROWS('vw_holdings_price_validation') - SUM('vw_holdings_price_validation'[is_price_null]), COUNTROWS('vw_holdings_price_validation'))"
            },
            {
                "name": "Bid Value Completeness %",
                "expression": "DIVIDE(COUNTROWS('vw_holdings_price_validation') - SUM('vw_holdings_price_validation'[is_bid_value_null]), COUNTROWS('vw_holdings_price_validation'))"
            }
        ]
    
    def _build_metadata_json(self) -> str:
        """Build metadata file."""
        metadata = {
            "name": "Holdings*Price Reconciliation Validator",
            "description": "Data quality validation report for holdings * bid price reconciliation check (98-102% tolerance)",
            "version": "1.0.0",
            "createdDate": datetime.now().isoformat(),
            "author": "DFM Pipeline",
            "tags": ["reconciliation", "data-quality", "validation", "finance"]
        }
        return json.dumps(metadata, indent=2)
    
    def _get_default_theme(self) -> str:
        """Return default Power BI theme."""
        theme = {
            "name": "Default",
            "colors": {
                "good": "#70AD47",
                "neutral": "#4472C4",
                "bad": "#C5504E",
                "warning": "#F79646"
            }
        }
        return json.dumps(theme, indent=2)


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Generate Power BI report for Holdings*Price reconciliation validation"
    )
    parser.add_argument("--workspace-id", default="", help="Fabric workspace ID")
    parser.add_argument("--database-server", default="", help="Fabric SQL server (e.g., tenant.analysis.windows.net)")
    parser.add_argument("--database-name", default="default", help="Database name")
    parser.add_argument("--output-path", default="./reports/holdings_price_validator.pbix", 
                       help="Output .pbix file path")
    
    args = parser.parse_args()
    
    generator = PowerBIReportGenerator(args.output_path)
    generator.create_report(
        workspace_id=args.workspace_id,
        database_server=args.database_server,
        database_name=args.database_name
    )
    
    print("\n[SUCCESS] Power BI report generated successfully!")
    print(f"[ACTION] Open the report in Power BI Desktop: {args.output_path}")
    print("\nNext steps:")
    print("1. Open the .pbix file in Power BI Desktop")
    print("2. Go to File > Recent sources to update the Fabric SQL connection details")
    print("3. Configure the data refresh schedule")
    print("4. Publish to your Fabric workspace")


if __name__ == "__main__":
    main()
