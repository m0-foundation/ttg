#!/usr/bin/env bash
set -e

sizes=false

while getopts p:s flag
do
    case "${flag}" in
        p) profile=${OPTARG};;
        s) sizes=true;;
    esac
done

export FOUNDRY_PROFILE=$profile
echo Using profile: $FOUNDRY_PROFILE

if [ "$sizes" = false ];
then
    forge build --skip '*/test/**/*.t.sol' --skip '*/script/**' --skip '*/lib/forge-std/**' --extra-output-files abi;
else
    forge build --skip '*/test/**/*.t.sol' --skip '*/script/**' --skip '*/lib/forge-std/**' --extra-output-files abi --sizes;
fi

mkdir -p abi

cp ./out/DualGovernor.sol/DualGovernor.abi.json ./abi/DualGovernor.json
cp ./out/PowerBootstrapToken.sol/PowerBootstrapToken.abi.json ./abi/PowerBootstrapToken.json
cp ./out/PowerToken.sol/PowerToken.abi.json ./abi/PowerToken.json
cp ./out/Registrar.sol/Registrar.abi.json ./abi/Registrar.json
cp ./out/ZeroToken.sol/ZeroToken.abi.json ./abi/ZeroToken.json

mkdir -p bytecode

DualGovernorBytecode=$(jq '.bytecode.object' ./out/DualGovernor.sol/DualGovernor.json)
PowerBootstrapTokenBytecode=$(jq '.bytecode.object' ./out/PowerBootstrapToken.sol/PowerBootstrapToken.json)
PowerTokenBytecode=$(jq '.bytecode.object' ./out/PowerToken.sol/PowerToken.json)
RegistrarBytecode=$(jq '.bytecode.object' ./out/Registrar.sol/Registrar.json)
ZeroTokenBytecode=$(jq '.bytecode.object' ./out/ZeroToken.sol/ZeroToken.json)

echo "{ \"bytecode\": ${DualGovernorBytecode} }" > ./bytecode/DualGovernor.json
echo "{ \"bytecode\": ${PowerBootstrapTokenBytecode} }" > ./bytecode/PowerBootstrapToken.json
echo "{ \"bytecode\": ${PowerTokenBytecode} }" > ./bytecode/PowerToken.json
echo "{ \"bytecode\": ${RegistrarBytecode} }" > ./bytecode/Registrar.json
echo "{ \"bytecode\": ${ZeroTokenBytecode} }" > ./bytecode/ZeroToken.json
