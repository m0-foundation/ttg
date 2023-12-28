#!/usr/bin/env bash
set -e

sizes=false

while getopts p:s flag; do
	case "${flag}" in
	p) profile=${OPTARG} ;;
	s) sizes=true ;;
	esac
done

export FOUNDRY_PROFILE=$profile
echo Using profile: $FOUNDRY_PROFILE

if [ "$sizes" = false ]; then
	forge build --skip '*/test/**/*.t.sol' --skip '*/script/**' --skip '*/lib/forge-std/**' --extra-output-files abi
else
	forge build --skip '*/test/**/*.t.sol' --skip '*/script/**' --skip '*/lib/forge-std/**' --extra-output-files abi --sizes
fi

mkdir -p abi

cp ./out/EmergencyGovernor.sol/EmergencyGovernor.abi.json ./abi/EmergencyGovernor.json
cp ./out/EmergencyGovernorDeployer.sol/EmergencyGovernorDeployer.abi.json ./abi/EmergencyGovernorDeployer.json
cp ./out/StandardGovernor.sol/StandardGovernor.abi.json ./abi/StandardGovernor.json
cp ./out/StandardGovernorDeployer.sol/StandardGovernorDeployer.abi.json ./abi/StandardGovernorDeployer.json
cp ./out/ZeroGovernor.sol/ZeroGovernor.abi.json ./abi/ZeroGovernor.json
cp ./out/PowerBootstrapToken.sol/PowerBootstrapToken.abi.json ./abi/PowerBootstrapToken.json
cp ./out/PowerToken.sol/PowerToken.abi.json ./abi/PowerToken.json
cp ./out/PowerTokenDeployer.sol/PowerTokenDeployer.abi.json ./abi/PowerTokenDeployer.json
cp ./out/Registrar.sol/Registrar.abi.json ./abi/Registrar.json
cp ./out/ZeroToken.sol/ZeroToken.abi.json ./abi/ZeroToken.json
cp ./out/DistributionVault.sol/DistributionVault.abi.json ./abi/DistributionVault.json
cp ./out/ERC20ExtendedHarness.sol/ERC20ExtendedHarness.abi.json ./abi/ERC20ExtendedHarness.json

mkdir -p bytecode

EmergencyGovernorBytecode=$(jq '.bytecode.object' ./out/EmergencyGovernor.sol/EmergencyGovernor.json)
EmergencyGovernorDeployerBytecode=$(jq '.bytecode.object' ./out/EmergencyGovernorDeployer.sol/EmergencyGovernorDeployer.json)
StandardGovernorBytecode=$(jq '.bytecode.object' ./out/StandardGovernor.sol/StandardGovernor.json)
StandardGovernorDeployerBytecode=$(jq '.bytecode.object' ./out/StandardGovernorDeployer.sol/StandardGovernorDeployer.json)
ZeroGovernorBytecode=$(jq '.bytecode.object' ./out/ZeroGovernor.sol/ZeroGovernor.json)
PowerBootstrapTokenBytecode=$(jq '.bytecode.object' ./out/PowerBootstrapToken.sol/PowerBootstrapToken.json)
PowerTokenBytecode=$(jq '.bytecode.object' ./out/PowerToken.sol/PowerToken.json)
PowerTokenDeployerBytecode=$(jq '.bytecode.object' ./out/PowerTokenDeployer.sol/PowerTokenDeployer.json)
RegistrarBytecode=$(jq '.bytecode.object' ./out/Registrar.sol/Registrar.json)
ZeroTokenBytecode=$(jq '.bytecode.object' ./out/ZeroToken.sol/ZeroToken.json)
DistributionVaultBytecode=$(jq '.bytecode.object' ./out/DistributionVault.sol/DistributionVault.json)
ERC20ExtendedHarnessBytecode=$(jq '.bytecode.object' ./out/ERC20ExtendedHarness.sol/ERC20ExtendedHarness.json)

echo "{ \"bytecode\": ${EmergencyGovernorBytecode} }" >./bytecode/EmergencyGovernor.json
echo "{ \"bytecode\": ${EmergencyGovernorDeployerBytecode} }" >./bytecode/EmergencyGovernorDeployer.json
echo "{ \"bytecode\": ${StandardGovernorBytecode} }" >./bytecode/StandardGovernor.json
echo "{ \"bytecode\": ${StandardGovernorDeployerBytecode} }" >./bytecode/StandardGovernorDeployer.json
echo "{ \"bytecode\": ${ZeroGovernorBytecode} }" >./bytecode/ZeroGovernor.json
echo "{ \"bytecode\": ${PowerBootstrapTokenBytecode} }" >./bytecode/PowerBootstrapToken.json
echo "{ \"bytecode\": ${PowerTokenBytecode} }" >./bytecode/PowerToken.json
echo "{ \"bytecode\": ${PowerTokenDeployerBytecode} }" >./bytecode/PowerTokenDeployer.json
echo "{ \"bytecode\": ${RegistrarBytecode} }" >./bytecode/Registrar.json
echo "{ \"bytecode\": ${ZeroTokenBytecode} }" >./bytecode/ZeroToken.json
echo "{ \"bytecode\": ${DistributionVaultBytecode} }" >./bytecode/DistributionVault.json
echo "{ \"bytecode\": ${ERC20ExtendedHarnessBytecode} }" >./bytecode/ERC20ExtendedHarness.json
