import pyautogui as pg
import time
import os

# ------ Adjust your paths here ------
input_folder = r"D:\Guien MEMS Lab Final\saigou_no_jiken\ts158"
export_folder = os.path.join(input_folder, "export")
os.makedirs(export_folder, exist_ok=True)

# ------ Set delay to safely interact with GUI ------
pg.PAUSE = 0.0  # 1 second between each PyAutoGUI action

# Get all files (excluding directories)
files = [f for f in os.listdir(input_folder) if os.path.isfile(os.path.join(input_folder, f))]

# Allow user to quickly switch to Universal Analysis window
print("You have 5 seconds to activate the Universal Analysis window...")
time.sleep(5)

for file in files:
    input_file = os.path.join(input_folder, file)
    export_file = os.path.join(export_folder, file + ".txt")

    # STEP 1: Open file (Ctrl+O)
    pg.hotkey('ctrl', 'o')
    time.sleep(0.5)

    # Type file path
    pg.write(input_file)
    pg.press('enter')
    time.sleep(0.1)

    # Extra confirmation (press enter again)
    pg.press('enter')
    time.sleep(0.2)

    # STEP 2: Navigate menu (File > Export Data File > TTS Signals)
    pg.press('alt')     # Activate menu bar
    time.sleep(0.3)
    pg.press('f')       # File menu
    time.sleep(0.3)

    # Navigate down to 'Export Data File' (adjust the number of presses if needed)
    for _ in range(11):
        pg.press('down')
        time.sleep(0.01)
    
    pg.press('right')   # Expand submenu
    time.sleep(0.5)
    pg.press('enter')   # Select 'TTS Signals'
    time.sleep(0.2)

    # STEP 3: Confirm export settings (Spreadsheet + Unicode default)
    pg.press('enter')
    time.sleep(0.3)

    # STEP 4: Save file to export folder
    pg.write(export_file)
    pg.press('enter')
    time.sleep(0.3)

    # STEP 5: Close current file (Alt+F, Close)
    pg.press('alt')
    time.sleep(0.5)
    pg.press('f')
    time.sleep(0.5)
    pg.press('c')
    time.sleep(0.3)

    # If asked to save changes, press 'n' (No)
    pg.press('enter')
    time.sleep(0.3)

print("✅ Done exporting all files successfully!")