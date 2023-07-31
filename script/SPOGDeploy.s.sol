// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { IVALUE, IVOTE } from "../src/interfaces/ITokens.sol";

import { DualGovernor } from "../src/core/governor/DualGovernor.sol";
import { SPOG } from "../src/core/SPOG.sol";
import { SPOGVault } from "../src/periphery/SPOGVault.sol";
import { VALUE } from "../src/tokens/VALUE.sol";
import { VOTE } from "../src/tokens/VOTE.sol";
import { VoteAuction } from "../src/periphery/VoteAuction.sol";

import { console, ERC20Mock } from "./ImportedContracts.sol";
import { BaseScript } from "./shared/Base.s.sol";

contract SPOGDeployScript is BaseScript {
    address public governor;
    address public spog;

    uint256 public voteQuorum;
    uint256 public valueQuorum;
    address public cash;
    uint256 public tax;
    uint256 public taxLowerBound;
    uint256 public taxUpperBound;
    uint256 public inflator;
    uint256 public fixedReward;

    address public vote;
    address public value;
    address public vault;
    address public auction;

    function setUp() public override {
        super.setUp();

        vm.startBroadcast(deployer);

        cash = address(new ERC20Mock("CashToken", "CASH", msg.sender, 100e18));

        inflator = 20; // 20%
        fixedReward = 100 * 10e18;

        voteQuorum = 65; // 65%
        valueQuorum = 65; // 65%
        tax = 5e18;
        taxLowerBound = 0;
        taxUpperBound = 6e18;

        value = address(new VALUE("SPOG Value", "VALUE"));
        vote = address(new VOTE("SPOG Vote", "VOTE", value));
        auction = address(new VoteAuction());

        // deploy governor and vaults
        governor = address(new DualGovernor("DualGovernor", vote, value, voteQuorum, valueQuorum));
        vault = address(new SPOGVault(governor));

        // grant minter role for test runner
        IVOTE(vote).grantRole(IVOTE(vote).MINTER_ROLE(), msg.sender);
        IVALUE(value).grantRole(IVALUE(value).MINTER_ROLE(), msg.sender);

        vm.stopBroadcast();
    }

    function run() public {
        setUp();

        vm.startBroadcast(deployer);

        SPOG.Configuration memory config = SPOG.Configuration(
            governor,
            vault,
            cash,
            tax,
            taxLowerBound,
            taxUpperBound,
            inflator,
            fixedReward
        );

        spog = address(new SPOG(config));

        console.log("SPOG address: ", spog);
        console.log("VOTE token address: ", vote);
        console.log("VALUE token address: ", value);
        console.log("DualGovernor address: ", governor);
        console.log("Cash address: ", cash);
        console.log("Vault address: ", vault);

        vm.stopBroadcast();
    }
}
