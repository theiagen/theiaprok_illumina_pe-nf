#!/usr/bin/env python3
"""
Standalone Python script to create failure reports for THEIAPROK_ILLUMINA_PE workflow.
This script generates detailed JSON reports for samples that fail at various stages.
"""

import json
import datetime
import argparse
import sys
import os
from pathlib import Path


def parse_arguments():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(
        description="Create failure report for THEIAPROK_ILLUMINA_PE workflow"
    )
    
    parser.add_argument(
        "--sample_id",
        required=True,
        help="Sample identifier"
    )
    
    parser.add_argument(
        "--fail_type",
        required=True,
        choices=["RAW_SCREEN_FAIL", "CLEAN_SCREEN_FAIL", "ASSEMBLY_FAIL", "OTHER"],
        help="Type of failure"
    )
    
    parser.add_argument(
        "--fail_reason",
        required=True,
        help="Detailed reason for failure"
    )
    
    parser.add_argument(
        "--output_file",
        required=True,
        help="Output JSON file path"
    )
    
    parser.add_argument("--min_reads", type=int, default=7472)
    parser.add_argument("--min_basepairs", type=int, default=2241820)
    parser.add_argument("--min_genome_length", type=int, default=100000)
    parser.add_argument("--max_genome_length", type=int, default=18040666)
    parser.add_argument("--min_coverage", type=int, default=10)
    parser.add_argument("--min_proportion", type=int, default=40)
    
    parser.add_argument(
        "--metadata_json",
        help="JSON string containing sample metadata"
    )
    
    parser.add_argument(
        "--workflow_name",
        default="THEIAPROK_ILLUMINA_PE",
        help="Name of the workflow"
    )
    
    return parser.parse_args()


def get_recommendations(fail_type):
    """Get specific recommendations based on failure type."""
    recommendations = {
        "RAW_SCREEN_FAIL": [
            "Check read quality and quantity",
            "Consider adjusting min_reads or min_basepairs parameters",
            "Verify sequencing depth is adequate",
        ],
        "CLEAN_SCREEN_FAIL": [
            "Raw reads passed but cleaned reads failed",
            "Check trimming parameters - they may be too aggressive",
            "Verify adapter sequences are correct"
        ],
        "ASSEMBLY_FAIL": [
            "Assembly process failed",
            "Check read quality after trimming",
            "Check for memory or computational resource limitations",
            "Consider using a different assembler"
        ],
        "OTHER": [
            "Unknown failure type",
            "Check workflow logs for more details",
            "Contact workflow maintainer",
            "Review process-specific error messages"
        ]
    }
    
    return recommendations.get(fail_type, recommendations["OTHER"])


def create_failure_report(args):
    """Create the failure report JSON."""
    
    sample_metadata = {}
    if args.metadata_json:
        try:
            sample_metadata = json.loads(args.metadata_json)
        except json.JSONDecodeError as e:
            print(f"Warning: Could not parse metadata JSON: {e}", file=sys.stderr)
            sample_metadata = {"id": args.sample_id}
    else:
        sample_metadata = {"id": args.sample_id}
    
    # Create the failure report structure
    failure_data = {
        "sample_id": args.sample_id,
        "failure_type": args.fail_type,
        "failure_reason": args.fail_reason,
        "timestamp": datetime.datetime.now().isoformat(),
        "workflow_name": args.workflow_name,
        "parameters": {
            "min_reads": args.min_reads,
            "min_basepairs": args.min_basepairs,
            "min_genome_length": args.min_genome_length,
            "max_genome_length": args.max_genome_length,
            "min_coverage": args.min_coverage,
            "min_proportion": args.min_proportion
        },
        "sample_metadata": sample_metadata,
        "recommendations": get_recommendations(args.fail_type),
        "troubleshooting": {
            "check_logs": f"Review logs for sample {args.sample_id}",
            "parameter_adjustment": "Consider adjusting workflow parameters based on recommendations",
            "rerun_strategy": "May require re-sequencing or parameter optimization"
        }
    }
    
    # Add failure specific diagnostic information
    if args.fail_type == "RAW_SCREEN_FAIL":
        failure_data["diagnostic_info"] = {
            "check_raw_reads": "fastq_scan or similar tool output",
            "expected_vs_actual": "Compare actual values to minimum thresholds",
            "common_causes": ["Low sequencing depth", "Poor read quality", "Adapter contamination"]
        }
    elif args.fail_type == "CLEAN_SCREEN_FAIL":
        failure_data["diagnostic_info"] = {
            "check_trimming": "Review trimming statistics",
            "before_after_comparison": "Compare raw vs cleaned read statistics",
            "common_causes": ["Over-aggressive trimming", "Unusual adapter patterns", "Quality score issues"]
        }
    elif args.fail_type == "ASSEMBLY_FAIL":
        failure_data["diagnostic_info"] = {
            "check_assembly_logs": "Review assembler output and error messages",
            "resource_usage": "Check memory and CPU usage during assembly",
            "common_causes": ["Insufficient coverage", "High complexity regions", "Resource limitations"]
        }
    
    return failure_data


def main():
    """Main function."""
    args = parse_arguments()
    
    try:
        # Create the failure report
        failure_data = create_failure_report(args)
        
        output_path = Path(args.output_file)
        output_path.parent.mkdir(parents=True, exist_ok=True)
    
        with open(output_path, 'w') as f:
            json.dump(failure_data, f, indent=2)
        
        print(f"Failure report created for sample {args.sample_id}")
        print(f"Report saved to: {output_path}")
        
        return 0
        
    except Exception as exc:
        print(f"Error creating failure report: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())