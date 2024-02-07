# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

# dapp deps
update:; forge update

# coverage report
coverage :; forge coverage --report lcov && lcov --remove ./lcov.info -o ./lcov.info 'script/*' 'test/*' && genhtml lcov.info --branch-coverage --output-dir coverage

# Deployment helpers
deploy :; FOUNDRY_PROFILE=production forge script script/Deploy.s.sol --rpc-url mainnet --broadcast -vvv
deploy-sepolia :; FOUNDRY_PROFILE=sepolia forge script script/Deploy.s.sol --rpc-url sepolia --broadcast -vvv
deploy-local :; FOUNDRY_PROFILE=production forge script script/Deploy.s.sol --rpc-url localhost --broadcast -v

# Run slither
slither :; FOUNDRY_PROFILE=production forge build --build-info --skip '*/test/**' --skip '*/script/**' --force && slither --compile-force-framework foundry --ignore-compile --sarif results.sarif --config-file slither.config.json .

# Common tasks
build :; @./build.sh -p production
build-sepolia :; @./build.sh -p sepolia
tests :; @./test.sh -p default
gas :; @./test.sh -p production -g
sizes :; @./build.sh -p production -s
clean :; forge clean && rm -rf ./abi && rm -rf ./bytecode && rm -rf ./types
