// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;

import {StdCheats} from "forge-std/StdCheats.sol";
import {Vault} from "src/periphery/Vault.sol";
import {ISPOGGovernor} from "src/interfaces/ISPOGGovernor.sol";
import {BaseTest} from "test/Base.t.sol";
import {ERC20GodMode} from "test/mock/ERC20GodMode.sol";
import {ERC20PricelessAuction} from "src/periphery/ERC20PricelessAuction.sol";
import {IERC20PricelessAuction} from "src/interfaces/IERC20PricelessAuction.sol";

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
    IERC20PricelessAuction public auctionImplementation;
    Vault public vault;
    address spogAddress;

    // events to test
    event EpochRewardsDeposit(uint256 indexed epoch, address token, uint256 amount);

    ERC20GodMode internal voteToken = new ERC20GodMode("Vote Token", "VOTE", 18);

    event VoteGovernorUpdated(address indexed newVoteGovernor, address indexed newVotingToken);

    function setUp() public {
        ISPOGGovernor voteGovernor = ISPOGGovernor(address(new MockSPOGGovernor(address(voteToken))));
        ISPOGGovernor valueGovernor = ISPOGGovernor(address(new MockSPOGGovernor(address(voteToken))));
        auctionImplementation = new ERC20PricelessAuction();
        vault = new Vault(voteGovernor, valueGovernor, auctionImplementation);
        spogAddress = vault.voteGovernor().spogAddress();

        // mint tokens to vault
        deal({token: address(dai), to: address(vault), give: 1000e18, adjust: true});
    }

    function test_Revert_UpdateVoteGovernor_WhenCalledNoBySPOG() public {
        vm.startPrank(users.alice);

        ISPOGGovernor newVoteGovernor = ISPOGGovernor(address(new MockSPOGGovernor(address(voteToken))));
        vm.expectRevert("Vault: Only spog");
        vault.updateVoteGovernor(newVoteGovernor);

        vm.stopPrank();
    }

    function test_depositEpochRewardTokens() public {
        setUp();

        // deposit rewards for previous epoch
        uint256 epoch = 1;
        voteToken.mint(spogAddress, 1000e18);
        vm.startPrank(spogAddress);
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
        voteToken.mint(spogAddress, 1000e18);
        vm.startPrank(spogAddress);
        voteToken.approve(address(vault), 1000e18);
        vault.depositEpochRewardTokens(epoch, address(voteToken), 1000e18);
        vm.stopPrank();

        uint256 unclaimed = vault.unclaimedVoteTokensForEpoch(epoch);

        assertEq(unclaimed, 1000e18);
    }

    function test_sellUnclaimedVoteTokens_Vault() public {
        setUp();

        // deposit rewards for previous epoch
        uint256 epoch = 1;
        voteToken.mint(spogAddress, 1000e18);
        vm.startPrank(spogAddress);
        voteToken.approve(address(vault), 1000e18);
        vault.depositEpochRewardTokens(epoch, address(voteToken), 1000e18);

        vault.sellUnclaimedVoteTokens(epoch, address(usdc), 30 days);

        assertEq(voteToken.balanceOf(address(vault)), 0);
        vm.stopPrank();
    }

    function test_UpdateVoteGovernor() public {
        vm.startPrank(spogAddress);

        ISPOGGovernor newVoteGovernor = ISPOGGovernor(address(new MockSPOGGovernor(address(voteToken))));
        expectEmit();
        emit VoteGovernorUpdated(address(newVoteGovernor), address(voteToken));
        vault.updateVoteGovernor(newVoteGovernor);

        assertEq(address(vault.voteGovernor()), address(newVoteGovernor), "Governor was not updated");
    }

    function test_fallback() public {
        vm.expectRevert("Vault: non-existent function");
        (bool success,) = address(vault).call(abi.encodeWithSignature("doesNotExist()"));

        assertEq(success, true);
    }
}
