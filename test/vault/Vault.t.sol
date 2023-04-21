// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;

import {StdCheats} from "forge-std/StdCheats.sol";
import {Vault} from "src/periphery/Vault.sol";
import {ISPOGGovernor} from "src/interfaces/ISPOGGovernor.sol";
import {BaseTest} from "test/Base.t.sol";
import {ERC20GodMode} from "test/mock/ERC20GodMode.sol";

contract MockSPOGGovernor is StdCheats {
    address public immutable spogAddress;
    address public immutable votingToken;

    constructor(address _votingToken) {
        spogAddress = makeAddr("spog");
        votingToken = _votingToken;
    }

    function currentVotingPeriodEpoch() public pure returns (uint256) {
        return 2;
    }
}

contract VaultTest is BaseTest {
    Vault public vault;

    // events to test
    event EpochRewardsDeposit(uint256 indexed epoch, address token, uint256 amount);

    ERC20GodMode internal voteToken = new ERC20GodMode("Vote Token", "VOTE", 18);

    function setUp() public {
        ISPOGGovernor voteGovernorAddress = ISPOGGovernor(address(new MockSPOGGovernor(address(voteToken))));
        ISPOGGovernor valueGovernorAddress = ISPOGGovernor(address(new MockSPOGGovernor(address(voteToken))));
        vault = new Vault(voteGovernorAddress, valueGovernorAddress);

        // mint tokens to vault
        deal({token: address(dai), to: address(vault), give: 1000e18, adjust: true});
    }

    function test_depositEpochRewardTokens() public {
        setUp();

        // deposit rewards for previous epoch
        uint256 epoch = 1;
        voteToken.mint(address(vault.voteGovernor()), 1000e18);
        vm.startPrank(address(vault.voteGovernor()));
        voteToken.approve(address(vault), 1000e18);

        expectEmit();
        emit EpochRewardsDeposit(epoch, address(voteToken), 1000e18);
        vault.depositEpochRewardTokens(epoch, address(voteToken), 1000e18);
        vm.stopPrank();

        assertEq(voteToken.balanceOf(address(vault)), 1000e18);
    }

    function test_unclaimedVoteTokensForEpoch() public {
        setUp();

        // deposit rewards for previous epoch
        uint256 epoch = 1;
        voteToken.mint(address(vault.voteGovernor()), 1000e18);
        vm.startPrank(address(vault.voteGovernor()));
        voteToken.approve(address(vault), 1000e18);
        vault.depositEpochRewardTokens(epoch, address(voteToken), 1000e18);
        vm.stopPrank();

        uint256 unclaimed = vault.unclaimedVoteTokensForEpoch(epoch);

        assertEq(unclaimed, 1000e18);
    }

    function test_sellUnclaimedVoteTokens() public {
        setUp();

        // deposit rewards for previous epoch
        uint256 epoch = 1;
        voteToken.mint(address(vault.voteGovernor()), 1000e18);
        vm.startPrank(address(vault.voteGovernor()));
        voteToken.approve(address(vault), 1000e18);
        vault.depositEpochRewardTokens(epoch, address(voteToken), 1000e18);
        vm.stopPrank();

        vm.prank(vault.voteGovernor().spogAddress());
        vault.sellUnclaimedVoteTokens(epoch, address(usdc), 30 days);

        assertEq(voteToken.balanceOf(address(vault)), 0);
    }
}
