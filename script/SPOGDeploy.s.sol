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
    uint256 public constant DEPLOYER_STARTING_NONCE = 0;

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

        address expectedSpog = _getContractFrom(deployer, DEPLOYER_STARTING_NONCE + 5);

        value = address(new VALUE("SPOG Value", "VALUE", expectedSpog));
        vault = address(new SPOGVault(value));
        cash = address(new ERC20Mock("CashToken", "CASH", msg.sender, 100e18));
        auction = address(new VoteAuction());
        governanceDeployer = address(new GovernanceDeployer(expectedSpog));

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

    function _getContractFrom(address account, uint256 nonce) internal pure returns (address) {
        return
            address(
                uint160(
                    uint256(
                        keccak256(
                            nonce == 0x00
                                ? abi.encodePacked(bytes1(0xd6), bytes1(0x94), account, bytes1(0x80))
                                : nonce <= 0x7f
                                ? abi.encodePacked(bytes1(0xd6), bytes1(0x94), account, uint8(nonce))
                                : nonce <= 0xff
                                ? abi.encodePacked(bytes1(0xd7), bytes1(0x94), account, bytes1(0x81), uint8(nonce))
                                : nonce <= 0xffff
                                ? abi.encodePacked(bytes1(0xd8), bytes1(0x94), account, bytes1(0x82), uint16(nonce))
                                : nonce <= 0xffffff
                                ? abi.encodePacked(bytes1(0xd9), bytes1(0x94), account, bytes1(0x83), uint24(nonce))
                                : abi.encodePacked(bytes1(0xda), bytes1(0x94), account, bytes1(0x84), uint32(nonce))
                        )
                    )
                )
            );
    }
}
