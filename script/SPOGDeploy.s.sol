// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { IVALUE, IVOTE } from "../src/interfaces/ITokens.sol";
import { ISPOGGovernor } from "../src/interfaces/ISPOGGovernor.sol";

import { GovernanceDeployer } from "../src/deployer/GovernanceDeployer.sol";
import { SPOG } from "../src/core/SPOG.sol";
import { SPOGVault } from "../src/periphery/SPOGVault.sol";
import { VALUE } from "../src/tokens/VALUE.sol";
import { VoteAuction } from "../src/periphery/VoteAuction.sol";

import { console, ERC20Mock } from "./ImportedContracts.sol";
import { BaseScript } from "./shared/Base.s.sol";

contract SPOGDeployScript is BaseScript {
    address public governanceDeployer;
    address public governor;
    address public spog;

    uint256 public voteQuorum = 4; // 4%
    uint256 public valueQuorum = 4; // 4%
    address public cash;
    uint256 public tax = 5e18;
    uint256 public taxLowerBound = 0;
    uint256 public taxUpperBound = 6e18;
    uint256 public inflator = 20; // 20%
    uint256 public fixedReward = 100 * 10e18;

    address public vote;
    address public value;
    address public vault;
    address public auction;

    function setUp() public override {
        super.setUp();
    }

    function run() public {
        vm.startBroadcast(deployer);

        address expectedSpog = address(0x29b2440db4A256B0c1E6d3B4CDcaA68E2440A08f);

        value = address(new VALUE("SPOG Value", "VALUE", expectedSpog)); // 0xBd770416a3345F91E4B34576cb804a576fa48EB1
        vault = address(new SPOGVault(value)); // 0x5a443704dd4B594B382c22a083e2BD3090A6feF3
        cash = address(new ERC20Mock("CashToken", "CASH", msg.sender, 100e18)); // 0x47e9Fbef8C83A1714F1951F142132E6e90F5fa5D
        auction = address(new VoteAuction()); // 0x8Be503bcdEd90ED42Eff31f56199399B2b0154CA
        governanceDeployer = address(new GovernanceDeployer(expectedSpog)); // 0x47c5e40890bcE4a473A49D7501808b9633F29782

        SPOG.Configuration memory config = SPOG.Configuration(
            governanceDeployer,
            value,
            vault,
            cash,
            tax,
            taxLowerBound,
            taxUpperBound,
            inflator,
            fixedReward,
            voteQuorum,
            valueQuorum
        );

        spog = address(new SPOG(config)); // 0x29b2440db4A256B0c1E6d3B4CDcaA68E2440A08f

        console.log("VALUE token address: ", value);
        console.log("Vault address: ", vault);
        console.log("Cash address: ", cash);
        console.log("Auction address: ", auction);
        console.log("Deployer address: ", governanceDeployer);
        console.log("SPOG address: ", spog);
        console.log("DualGovernor address: ", governor = SPOG(spog).governor());
        console.log("VOTE token address: ", vote = ISPOGGovernor(governor).vote());

        vm.stopBroadcast();
    }
}
