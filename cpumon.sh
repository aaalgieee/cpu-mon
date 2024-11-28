#!/bin/bash

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (sudo)"
    exit 1
fi

# Function to get CPU temperature
get_cpu_temp() {
    temp=$(cat /sys/class/thermal/thermal_zone0/temp)
    echo $((temp/1000))
}

# Function to control fan speed
control_fan() {
    current_temp=$(get_cpu_temp)
    
    # Set all available fans to 100%
    for hwmon in /sys/class/hwmon/hwmon*/
    do
        for pwm in "$hwmon"pwm[0-9]*
        do
            if [ -w "$pwm" ]; then
                # Enable manual control (if control file exists)
                control="${pwm}_enable"
                if [ -f "$control" ]; then
                    echo 1 > "$control"
                fi
                # Set fan to maximum speed
                echo 255 > "$pwm"
            fi
        done
    done
    
    echo "Fans set to 100% speed"
    echo "Current CPU temperature: ${current_temp}°C"
}

# Function to control CPU frequency
control_cpu_freq() {
    freq_khz=$(printf "%.0f\n" $(echo "$1 * 1000000" | bc))
    for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
        echo "$freq_khz" > "$cpu/cpufreq/scaling_max_freq"
    done
    echo "CPU frequency limit set to $1 GHz"
}

# Main loop to monitor power source
while true; do
    # Check if system is on AC power (Xiaomi path)
    status=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null)
    if [ "$status" = "Charging" ] || [ "$status" = "Full" ]; then
        on_ac_power=1
    else
        on_ac_power=0
    fi
    
    if [ "$on_ac_power" = "1" ]; then
        echo "AC power detected"
        control_cpu_freq 3.5
    else
        echo "Battery power detected"
        control_cpu_freq 2.2
    fi
    
    control_fan  # Always maximum
    
    # Check more frequently to respond to temperature changes
    sleep 2
done
