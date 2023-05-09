# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

# dapp deps
update:; forge update

# coverage report
coverage :; forge coverage --report lcov && lcov --remove ./lcov.info -o ./lcov.info 'script/*' 'test/*' && genhtml lcov.info --branch-coverage --output-dir coverage

# Deployment helpers

# deploy spog and mint cash, token and value to deployer + 5 addresses from the anvil mnemonic
deploy-spog-local :; forge script script/LocalTestDeployScript.s.sol --rpc-url localhost --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast -v

deploy-spog-sepolia :; forge script script/SPOGDeploy.s.sol --rpc-url sepolia --private-key ${ETH_PK} --broadcast -vvv

deploy-spog-qa-sepolia :; forge script script/LocalTestDeployScript.s.sol --rpc-url sepolia --broadcast -v
