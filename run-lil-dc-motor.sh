#!/bin/bash 


# This script essentially sets up the BB hardware to run 
# the "Li'l DC Motor Testbed", which drives a DC motor
# with PWM and direction pins

# It essentially does this to set up the hw:
#
# $ export SLOTS=$(find /sys/devices -name slots)
# $ echo am33xx_pwm > $SLOTS
# $ echo bone_pwm_P8_34 > $SLOTS
# $ echo bone_eqep1 > $SLOTS
# $ echo 110 > /sys/class/gpio/export
# $ echo 111 > /sys/class/gpio/export
# $ echo 112 > /sys/class/gpio/export


# Justin Pearson
# Jan 26, 2017


set -e  # bail if fail

# http://askubuntu.com/questions/15853/how-can-a-script-check-if-its-being-run-as-root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# set -x #echo on

###############################################
# First we just set the $SLOTS variable and load the DTOs and GPIOs.




# Ensure $SLOTS is defined
# http://stackoverflow.com/questions/3601515/how-to-check-if-a-variable-is-set-in-bash
if [ -z ${SLOTS+x} ]; then 
    echo "SLOTS is unset, setting it"; 
    export SLOTS=$(find /sys/devices -name slots)
else 
    echo "SLOTS is already set to '$SLOTS', good."; 
fi


# Ensure the relevant device-tree overlays are loaded
for dto in am33xx_pwm bone_pwm_P8_34 bone_eqep1; do
    if grep --quiet $dto $SLOTS; then
	echo "$dto in $SLOTS, good"
    else
	echo "$dto not in $SLOTS, loading it..."
	echo "dmesg before load:"
	dmesg | tail 
	echo $dto > $SLOTS
	echo "dmesg after load:"
	dmesg | tail
    fi
done 



# Load the GPIOs if they're not there.
pushd /sys/class/gpio/
for n in 110 111 112; do
    if [ ! -d "gpio$n" ]; then
	echo "Hm, GPIO $n not loaded? I'll load it."
	echo $n > export
    fi
    echo "out" > "gpio$n/direction" # set as an output
done
popd


# Find paths of the sysfs entries
# $ for x in pwm_test eqep; do declare ${x}_path="/sys/devices/booger/${x}"; echo ${x}_path; done; echo $pwm_test_path
# http://stackoverflow.com/questions/16553089/bash-dynamic-variable-names
for x in pwm_test eqep
do
    # Find the path of the sysfs entry
    mypath=$(find /sys/devices -iname "*$x*")
    if [ "$mypath" = "" ] 
    then
        echo "No path found for $x! What's up?"
        exit 1
    else
        echo "Found path for $x: $mypath with contents:"
        ls $mypath
    fi
    # Save name of path
    declare ${x}_path="${mypath}"   # pwm_test_path, eqep_path are now bash variables
done

echo 0 > $eqep_path/position
cd $pwm_test_path

echo "Turning off PWM..."
echo 0 > run
cat period > duty  # set to 0%



echo "Turning motor 100% PWM clockwise for a bit..."
# clockwise (according to motor driver datasheet)
echo 1 > /sys/class/gpio/gpio111/value  # IN1
echo 0 > /sys/class/gpio/gpio112/value  # IN2
echo 1 > /sys/class/gpio/gpio110/value  # STBY
echo 0 > duty # 100% duty
echo "EQEP before: "
cat $eqep_path/position
echo "Turning on in 1 sec..."
sleep 1 
echo "ON"
echo 1 > run
sleep .5
echo "OFF"
echo 0 > run
echo "EQEP after: "
cat $eqep_path/position
sleep 1

echo "Turning motor 100% PWM counter-clockwise for a bit..."
# Set motor to counter-clockwise
echo 0 > /sys/class/gpio/gpio111/value  # IN1
echo 1 > /sys/class/gpio/gpio112/value  # IN2
echo 1 > /sys/class/gpio/gpio110/value  # STBY
echo 0 > duty  # 100% duty
echo "EQEP before: "
cat $eqep_path/position
echo "Turning on in 1 sec..."
sleep 1
echo "ON"
echo 1 > run
sleep .5
echo "OFF"
echo 0 > run
echo "EQEP after: "
cat $eqep_path/position
sleep 1

echo "Setting motor to standby..."
echo 0 > /sys/class/gpio/gpio110/value  # STBY

echo "Verify motor doesn't turn."
echo "EQEP before: "
cat $eqep_path/position
echo 0 > duty  # 100% duty
echo "ON"
echo 1 > run
sleep 1
echo  "OFF"
echo 0 > run
echo "EQEP after:"
cat $eqep_path/position

echo "All done!"
