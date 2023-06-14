// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import "test/Base.t.sol";

import "src/periphery/ERC20PricelessAuction.sol";
import "src/periphery/vaults/VoteVault.sol";
import "src/core/governor/DualGovernor.sol";

contract MockSPOGGovernor is StdCheats {
    ISPOG public immutable spog;

    constructor() {
        spog = ISPOG(makeAddr("spog"));
    }

    function currentEpoch() public view returns (uint256) {
        return block.number / 5;
    }

    function startOf(uint256 epoch) public pure returns (uint256) {
        return epoch * 5;
    }

    function votingPeriod() public pure returns (uint256) {
        return 5;
    }
}

contract VoteVaultTest is BaseTest {
    IERC20PricelessAuction internal auctionImplementation;
    VoteVault internal vault;
    address internal spogAddress;
    ERC20GodMode internal voteToken;

    event EpochRewardsDeposit(uint256 indexed epoch, address indexed token, uint256 amount);

    function setUp() public {
        DualGovernor voteGovernor = DualGovernor(payable(address(new MockSPOGGovernor())));
        auctionImplementation = new ERC20PricelessAuction();
        vault = new VoteVault(address(voteGovernor), address(auctionImplementation));
        spogAddress = address(vault.governor().spog());
        voteToken = new ERC20GodMode("Vote Token", "VOTE", 18);
    }

    function test_deposit() public {
        setUp();

        // deposit rewards for previous epoch
        uint256 epoch = 1;
        voteToken.mint(spogAddress, 1000e18);
        vm.startPrank(spogAddress);
        voteToken.approve(address(vault), 1000e18);

        expectEmit();
        emit EpochRewardsDeposit(epoch, address(voteToken), 1000e18);
        vault.deposit(epoch, address(voteToken), 1000e18);
        vm.stopPrank();

        assertEq(voteToken.balanceOf(address(vault)), 1000e18);
    }
}
