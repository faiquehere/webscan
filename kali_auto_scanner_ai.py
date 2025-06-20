#!/usr/bin/env python3

import os
import subprocess
from datetime import datetime
from fpdf import FPDF

target = input("Enter the target domain or URL (e.g., example.com): ").strip()
timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
report_dir = f"webscan_ai_report_{timestamp}"
os.makedirs(report_dir, exist_ok=True)

tools = {
    "whois": f"whois {target}",
    "dnsenum": f"dnsenum {target}",
    "sublist3r": f"sublist3r -d {target}",
    "whatweb": f"whatweb --max-threads=10 {target}",
    "nmap": f"nmap -T4 -F -p 80,443 --script http-vuln* {target}",
    "nikto": f"nikto -host {target}",
    "curl_headers": f"curl -I -L {target}"
}

summary_file = os.path.join(report_dir, "full_report.txt")
with open(summary_file, "w") as final:
    for name, cmd in tools.items():
        print(f"[>] Running {name}...")
        try:
            output = subprocess.check_output(cmd, shell=True, stderr=subprocess.STDOUT, text=True)
        except subprocess.CalledProcessError as e:
            output = f"[!] Error running {name}: {e.output}"
        file_path = os.path.join(report_dir, f"{name}.txt")
        with open(file_path, "w") as f:
            f.write(output)
        final.write(f"\n\n===== {name.upper()} OUTPUT =====\n{output}\n")

print("\n[*] Sending final report to AI Security Analyzer...")
ai_output_txt = os.path.join(report_dir, "ai_summary.txt")
with open(ai_output_txt, "w") as f:
    subprocess.run(["ai-security-analyzer", "mode=file", "-t", summary_file], stdout=f, check=True)

print("[*] Saving AI explanation to PDF...")
pdf = FPDF()
pdf.add_page()
pdf.set_font("Courier", size=10)
with open(ai_output_txt, "r") as f:
    for line in f:
        if len(line.strip()) > 0:
            pdf.multi_cell(0, 6, line)

pdf_path = os.path.join(report_dir, "ai_summary.pdf")
pdf.output(pdf_path)
print(f"[+] PDF saved at: {pdf_path}")
