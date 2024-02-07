#!/usr/bin/env bash
set -e

gas=false
verbose=false

while getopts gp:t:v flag
do
    case "${flag}" in
        g) gas=true;;
        p) profile=${OPTARG};;
        t) test=${OPTARG};;
        v) verbose=true;;
    esac
done

export FOUNDRY_PROFILE=$profile
echo Using profile: $FOUNDRY_PROFILE
echo Higher verbosity: $verbose
echo Gas report: $gas
echo Test Match pattern: $test

if [ "$FOUNDRY_PROFILE" = "sepolia" ]; then
	timestamp=$(date +%s)
	timestamp=$(expr $timestamp - 86400)
	sed -i '' "s/.*constant _MERGE_TIMESTAMP.*/    uint40 internal constant _MERGE_TIMESTAMP = $timestamp;/" src/libs/PureEpochs.sol
	sed -i '' "s/.*constant _EPOCH_PERIOD.*/    uint40 internal constant _EPOCH_PERIOD = 400 seconds;/" src/libs/PureEpochs.sol
fi

if [ "$verbose" = false ];
then
    verbosity="-vv"
else
    verbosity="-vvvv"
fi

if [ "$gas" = false ];
then
    gasReport=""
else
    gasReport="--gas-report"
fi

if [ -z "$test" ];
then
    forge test --match-path "test/*" $gasReport;
else
    forge test --match-test "$test" $gasReport $verbosity;
fi

sed -i '' "s/.*constant _MERGE_TIMESTAMP.*/    uint40 internal constant _MERGE_TIMESTAMP = 1_663_224_162;/" src/libs/PureEpochs.sol
sed -i '' "s/.*constant _EPOCH_PERIOD.*/    uint40 internal constant _EPOCH_PERIOD = 15 days;/" src/libs/PureEpochs.sol
