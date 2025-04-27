#!/bin/bash

# --- Flutter Multi-Platform Runner --- #

set -e  # Exit immediately if a command exits with a non-zero status

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to show error and exit
error_exit() {
  echo -e "${RED}❌ Error: $1${NC}"
  exit 1
}

# Function to show success
success_msg() {
  echo -e "${GREEN}✅ $1${NC}"
}

# Ensure flutter is installed
which flutter >/dev/null 2>&1 || error_exit "Flutter not found in PATH."

# Main menu
while true; do
  echo -e "\nWhich platform do you want to run Flutter app on?"
  echo "  1) Android (emulator)"
  echo "  2) iOS (simulator)"
  echo "  3) Web (Chrome)"
  echo "  4) Exit"
  read -p "Enter your choice [1-4]: " choice

  case $choice in
    1)
      echo "\nChecking Android emulator..."
      # Start emulator if none running
      if ! flutter devices | grep -q "android-arm64"; then
        flutter emulators --launch $(flutter emulators --launch | grep 'emulator' | head -n 1) || error_exit "Failed to launch Android emulator."
        sleep 10
      fi
      flutter run -d emulator-5554 || error_exit "Failed to run Flutter app on Android."
      success_msg "Flutter app running on Android emulator."
      break
      ;;

    2)
      echo "\nChecking iOS Simulator..."
      # Open iOS simulator if not open
      if ! pgrep Simulator >/dev/null; then
        open -a Simulator || error_exit "Failed to open Simulator."
        sleep 5
      fi
      DEVICE_ID=$(flutter devices | grep -i "iphone" | awk '{print $3}')
      flutter run -d $DEVICE_ID || error_exit "Failed to run Flutter app on iOS."
      success_msg "Flutter app running on iOS simulator."
      break
      ;;

    3)
      echo "\nRunning on Chrome browser..."
      flutter run -d chrome || error_exit "Failed to run Flutter app on Web (Chrome)."
      success_msg "Flutter app running on Web (Chrome)."
      break
      ;;

    4)
      echo "Exiting. Bye! 👋"
      exit 0
      ;;

    *)
      echo -e "${RED}❌ Invalid choice. Please try again.${NC}"
      ;;
  esac

done

/
To run:
*chmod +x flutter_multi_runner.sh
./flutter_multi_runner.sh
*/