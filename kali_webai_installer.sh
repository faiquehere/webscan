# Kali WebScan AI - Full Toolkit
# Directory: ~/webscan

# === 1. INSTALLER SCRIPT: kali_webai_installer.sh ===

#!/bin/bash

# Kali GPT - WebScan Installer + Runner (with Python venv for Sublist3r)
# Repo: github.com/faiquehere/webscan

set -e
export DEBIAN_FRONTEND=noninteractive

echo -e "\n[*] Updating packages and installing dependencies..."
sudo apt update -y
sudo apt install -y nmap nikto whatweb curl dnsenum whois python3 python3-pip python3-venv git

# Sublist3r setup
echo -e "\n[*] Installing or refreshing Sublist3r in /opt/Sublist3r..."
if [ ! -d "/opt/Sublist3r/.git" ]; then
  echo "[*] Cloning fresh copy of Sublist3r..."
  sudo rm -rf /opt/Sublist3r
  sudo git clone https://github.com/aboul3la/Sublist3r.git /opt/Sublist3r
else
  echo "[✓] Sublist3r repo already exists. Skipping clone."
fi

if [ ! -d "/opt/Sublist3r/venv" ]; then
  echo "[*] Creating virtual environment for Sublist3r..."
  sudo python3 -m venv /opt/Sublist3r/venv
fi

echo "[*] Installing Sublist3r dependencies..."
sudo /opt/Sublist3r/venv/bin/pip install --upgrade pip
sudo /opt/Sublist3r/venv/bin/pip install -r /opt/Sublist3r/requirements.txt

# CLI wrapper
if [ ! -f /usr/local/bin/sublist3r ]; then
  echo -e '#!/bin/bash\nsource /opt/Sublist3r/venv/bin/activate\npython /opt/Sublist3r/sublist3r.py "$@"' | sudo tee /usr/local/bin/sublist3r > /dev/null
  sudo chmod +x /usr/local/bin/sublist3r
  echo "[✓] Sublist3r command registered."
else
  echo "[✓] Sublist3r CLI already linked."
fi

# Dedicated venv for scanner
echo -e "\n[*] Creating dedicated venv for WebScan scripts..."
mkdir -p ~/webscan
python3 -m venv ~/webscan/venv
source ~/webscan/venv/bin/activate
pip install --upgrade pip
pip install ai-security-analyzer fpdf tqdm

# Download scanner script
echo -e "\n[*] Fetching scanner script from GitHub..."
cd ~/webscan
curl -sSL https://raw.githubusercontent.com/faiquehere/webscan/main/kali_auto_scanner_ai.py -o kali_auto_scanner_ai.py
chmod +x kali_auto_scanner_ai.py
deactivate

echo -e "\n[✓] Installation complete!"
read -p "Do you want to run the scanner now? [Y/n]: " confirm
if [[ "$confirm" =~ ^[Yy]?$ || "$confirm" == "" ]]; then
  echo -e "\n[*] Running WebScan...\n"
  source ~/webscan/venv/bin/activate
  python3 ~/webscan/kali_auto_scanner_ai.py
  deactivate
else
  echo "[*] You can run it anytime: source ~/webscan/venv/bin/activate && python3 ~/webscan/kali_auto_scanner_ai.py"
fi

# === END INSTALLER ===


# === 2. PYTHON SCRIPT: kali_auto_scanner_ai.py ===

#!/usr/bin/env python3

import os
import subprocess
from datetime import datetime
from fpdf import FPDF
from tqdm import tqdm

print("\nWebScan AI - Choose Scan Type")
print("1. Normal Scan (Fast)")
print("2. Detailed Scan (Comprehensive)")
choice = input("Enter choice [1/2]: ").strip()

basic_tools = ["whois", "sublist3r", "whatweb", "nmap", "nikto"]
detailed_tools = basic_tools + ["dnsenum", "curl_headers"]

tools_to_run = basic_tools if choice == '1' else detailed_tools

# Clean domain input
target = input("Enter the target domain (e.g., example.com): ").strip().replace("https://", "").replace("http://", "").split("/")[0]
timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
report_dir = f"webscan_{target}_{timestamp}"
os.makedirs(report_dir, exist_ok=True)

# Tool command definitions
commands = {
    "whois": f"whois {target}",
    "dnsenum": f"dnsenum {target}",
    "sublist3r": f"sublist3r -d {target}",
    "whatweb": f"whatweb --max-threads=10 {target}",
    "nmap": f"nmap -T4 --top-ports 100 --script http-vuln* {target}",
    "nikto": f"nikto -host {target}",
    "curl_headers": f"curl -I -L http://{target}"
}

summary_file = os.path.join(report_dir, "full_report.txt")
with open(summary_file, "w") as final:
    for name in tqdm(tools_to_run, desc="[+] Running Scanners", unit="tool"):
        cmd = commands[name]
        try:
            output = subprocess.check_output(cmd, shell=True, stderr=subprocess.STDOUT, text=True, timeout=90)
        except subprocess.CalledProcessError as e:
            output = f"[!] Error running {name}: {e.output}"
        except subprocess.TimeoutExpired:
            output = f"[!] Error: {name} scan timed out."
        file_path = os.path.join(report_dir, f"{name}.txt")
        with open(file_path, "w") as f:
            f.write(output)
        final.write(f"\n\n===== {name.upper()} OUTPUT =====\n{output}\n")

# AI Analysis
print("\n[*] Sending report to AI Security Analyzer...")
ai_output_txt = os.path.join(report_dir, "ai_summary.txt")
ai_analyzer_path = os.path.expanduser("~/webscan/venv/bin/ai-security-analyzer")
with open(ai_output_txt, "w") as f:
    subprocess.run([ai_analyzer_path, "mode=file", "-t", summary_file], stdout=f, check=True)

# Generate PDF
print("[*] Saving summary to PDF...")
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
