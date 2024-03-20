// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { IBatchGovernor } from "../src/abstract/interfaces/IBatchGovernor.sol";
import { IGovernor } from "../src/abstract/interfaces/IGovernor.sol";
import { IThresholdGovernor } from "../src/abstract/interfaces/IThresholdGovernor.sol";
import { IZeroGovernor } from "../src/interfaces/IZeroGovernor.sol";

import { MockBootstrapToken, MockEmergencyGovernor, MockEmergencyGovernorDeployer } from "./utils/Mocks.sol";
import { MockPowerTokenDeployer, MockStandardGovernor, MockStandardGovernorDeployer } from "./utils/Mocks.sol";
import { TestUtils } from "./utils/TestUtils.sol";
import { ZeroGovernorHarness } from "./utils/ZeroGovernorHarness.sol";

contract ZeroGovernorTests is TestUtils {
    address internal _cashToken1 = makeAddr("cashToken1");
    address internal _cashToken2 = makeAddr("cashToken2");

    uint256 internal _emergencyProposalQuorumNumerator = 9_000; // 90%
    uint256 internal _zeroProposalQuorumNumerator = 6_000; // 60%

    address[] internal _allowedCashTokens = [_cashToken1, _cashToken2];

    ZeroGovernorHarness internal _zeroGovernor;
    MockBootstrapToken internal _bootstrapToken;
    MockBootstrapToken internal _zeroToken;
    MockBootstrapToken internal _powerToken;
    MockEmergencyGovernor internal _emergencyGovernor;
    MockEmergencyGovernorDeployer internal _emergencyGovernorDeployer;
    MockPowerTokenDeployer internal _powerTokenDeployer;
    MockStandardGovernor internal _standardGovernor;
    MockStandardGovernorDeployer internal _standardGovernorDeployer;

    function setUp() external {
        _bootstrapToken = new MockBootstrapToken();
        _zeroToken = new MockBootstrapToken();
        _powerToken = new MockBootstrapToken();
        _emergencyGovernor = new MockEmergencyGovernor();
        _emergencyGovernorDeployer = new MockEmergencyGovernorDeployer();
        _powerTokenDeployer = new MockPowerTokenDeployer();
        _standardGovernor = new MockStandardGovernor();
        _standardGovernorDeployer = new MockStandardGovernorDeployer();

        _bootstrapToken.setTotalSupply(1);
        _zeroToken.setTotalSupply(1);
        _powerToken.setTotalSupply(1);

        _emergencyGovernor.setQuorumNumerator(1);
        _emergencyGovernorDeployer.setNextDeploy(address(_emergencyGovernor));

        _powerTokenDeployer.setNextDeploy(address(_powerToken));

        _standardGovernor.setVoteToken(address(_powerToken));
        _standardGovernor.setCashToken(_cashToken1);
        _standardGovernor.setProposalFee(1e18);

        _standardGovernorDeployer.setNextDeploy(address(_standardGovernor));

        _zeroGovernor = new ZeroGovernorHarness(
            address(_zeroToken),
            address(_emergencyGovernorDeployer),
            address(_powerTokenDeployer),
            address(_standardGovernorDeployer),
            address(_bootstrapToken),
            1,
            1,
            _zeroProposalQuorumNumerator,
            _allowedCashTokens
        );

        _standardGovernorDeployer.setLastDeploy(address(_standardGovernor));

        _emergencyGovernorDeployer.setLastDeploy(address(_emergencyGovernor));
    }

    function test_initialState() external view {
        assertEq(_zeroGovernor.voteToken(), address(_zeroToken));
        assertEq(_zeroGovernor.emergencyGovernorDeployer(), address(_emergencyGovernorDeployer));
        assertEq(_zeroGovernor.powerTokenDeployer(), address(_powerTokenDeployer));
        assertEq(_zeroGovernor.standardGovernorDeployer(), address(_standardGovernorDeployer));
        assertEq(_zeroGovernor.quorumDenominator(), 10_000);
        assertEq(_zeroGovernor.quorumNumerator(), _zeroProposalQuorumNumerator);
        assertEq(_zeroGovernor.isAllowedCashToken(_cashToken1), true);
        assertEq(_zeroGovernor.isAllowedCashToken(_cashToken2), true);
        assertEq(_zeroGovernor.emergencyGovernor(), address(_emergencyGovernor));
        assertEq(_zeroGovernor.standardGovernor(), address(_standardGovernor));
    }

    /* ============ constructor ============ */
    function test_constructor_invalidEmergencyGovernorDeployerAddress() external {
        vm.expectRevert(IZeroGovernor.InvalidEmergencyGovernorDeployerAddress.selector);
        new ZeroGovernorHarness(
            address(_zeroToken),
            address(0),
            address(_powerTokenDeployer),
            address(_standardGovernorDeployer),
            address(_bootstrapToken),
            1,
            1,
            _zeroProposalQuorumNumerator,
            _allowedCashTokens
        );
    }

    function test_constructor_invalidPowerTokenDeployerAddress() external {
        vm.expectRevert(IZeroGovernor.InvalidPowerTokenDeployerAddress.selector);
        new ZeroGovernorHarness(
            address(_zeroToken),
            address(_emergencyGovernorDeployer),
            address(0),
            address(_standardGovernorDeployer),
            address(_bootstrapToken),
            1,
            1,
            _zeroProposalQuorumNumerator,
            _allowedCashTokens
        );
    }

    function test_constructor_invalidStandardGovernorDeployerAddress() external {
        vm.expectRevert(IZeroGovernor.InvalidStandardGovernorDeployerAddress.selector);
        new ZeroGovernorHarness(
            address(_zeroToken),
            address(_emergencyGovernorDeployer),
            address(_powerTokenDeployer),
            address(0),
            address(_bootstrapToken),
            1,
            1,
            _zeroProposalQuorumNumerator,
            _allowedCashTokens
        );
    }

    function test_constructor_noAllowedCashTokens() external {
        vm.expectRevert(IZeroGovernor.NoAllowedCashTokens.selector);
        new ZeroGovernorHarness(
            address(_zeroToken),
            address(_emergencyGovernorDeployer),
            address(_powerTokenDeployer),
            address(_standardGovernorDeployer),
            address(_bootstrapToken),
            1,
            1,
            _zeroProposalQuorumNumerator,
            new address[](0)
        );
    }

    function test_constructor_invalidCashTokenAddress() external {
        vm.expectRevert(IZeroGovernor.InvalidCashTokenAddress.selector);
        new ZeroGovernorHarness(
            address(_zeroToken),
            address(_emergencyGovernorDeployer),
            address(_powerTokenDeployer),
            address(_standardGovernorDeployer),
            address(_bootstrapToken),
            1,
            1,
            _zeroProposalQuorumNumerator,
            new address[](1)
        );
    }

    /* ============ getProposal ============ */
    function test_getProposal_proposalDoesNotExist() external {
        vm.expectRevert(IBatchGovernor.ProposalDoesNotExist.selector);
        _zeroGovernor.getProposal(0);
    }

    function test_getProposal() external {
        _zeroToken.setTotalSupply(1_000_000);

        _zeroGovernor.setProposal({
            proposalId_: 1,
            voteStart_: _currentEpoch(),
            executed_: false,
            proposer_: address(1),
            quorumNumerator_: 4_000,
            noWeight_: 111,
            yesWeight_: 222
        });

        (
            uint48 voteStart_,
            uint48 voteEnd_,
            IGovernor.ProposalState state_,
            uint256 noVotes_,
            uint256 yesVotes_,
            address proposer_,
            uint256 quorum_,
            uint16 quorumNumerator_
        ) = _zeroGovernor.getProposal(1);

        assertEq(voteStart_, _currentEpoch());
        assertEq(voteEnd_, _currentEpoch() + 1);
        assertEq(uint8(state_), uint8(IGovernor.ProposalState.Active));
        assertEq(noVotes_, 111);
        assertEq(yesVotes_, 222);
        assertEq(proposer_, address(1));
        assertEq(quorum_, 400_000);
        assertEq(quorumNumerator_, 4_000);
    }

    /* ============ resetToPowerHolders ============ */
    function test_resetToPowerHolders_notZeroGovernor() external {
        vm.expectRevert(IBatchGovernor.NotSelf.selector);
        _zeroGovernor.resetToPowerHolders();
    }

    function test_resetToPowerHolders() external {
        address newStandardGovernor_ = makeAddr("newStandardGovernor");
        address newEmergencyGovernor_ = makeAddr("newEmergencyGovernor");
        address newPowerToken_ = makeAddr("newPowerToken");

        _standardGovernorDeployer.setNextDeploy(newStandardGovernor_);
        _emergencyGovernorDeployer.setNextDeploy(newEmergencyGovernor_);
        _powerTokenDeployer.setNextDeploy(newPowerToken_);

        vm.expectEmit();
        emit IZeroGovernor.ResetExecuted(
            address(_powerToken),
            newStandardGovernor_,
            newEmergencyGovernor_,
            newPowerToken_
        );

        vm.prank(address(_zeroGovernor));
        _zeroGovernor.resetToPowerHolders();
    }

    /* ============ resetToZeroHolders ============ */
    function test_resetToZeroHolders_notZeroGovernor() external {
        vm.expectRevert(IBatchGovernor.NotSelf.selector);
        _zeroGovernor.resetToZeroHolders();
    }

    function test_resetToZeroHolders() external {
        address newStandardGovernor_ = makeAddr("newStandardGovernor");
        address newEmergencyGovernor_ = makeAddr("newEmergencyGovernor");
        address newPowerToken_ = makeAddr("newPowerToken");

        _standardGovernorDeployer.setNextDeploy(newStandardGovernor_);
        _emergencyGovernorDeployer.setNextDeploy(newEmergencyGovernor_);
        _powerTokenDeployer.setNextDeploy(newPowerToken_);

        vm.expectEmit();
        emit IZeroGovernor.ResetExecuted(
            address(_zeroToken),
            newStandardGovernor_,
            newEmergencyGovernor_,
            newPowerToken_
        );

        vm.prank(address(_zeroGovernor));
        _zeroGovernor.resetToZeroHolders();
    }

    /* ============ setCashToken ============ */
    function test_setCashToken_callStandardGovernor() external {
        vm.expectCall(
            address(_standardGovernor),
            abi.encodeWithSignature("setCashToken(address,uint256)", _cashToken2, 1e18)
        );

        vm.prank(address(_zeroGovernor));
        _zeroGovernor.setCashToken(_cashToken2, 1e18);
    }

    function test_setCashToken_notZeroGovernor() external {
        vm.expectRevert(IBatchGovernor.NotSelf.selector);
        _zeroGovernor.setCashToken(_cashToken2, 1e18);
    }

    function test_setCashToken_invalidCashToken() external {
        vm.prank(address(_zeroGovernor));

        vm.expectRevert(IZeroGovernor.InvalidCashToken.selector);
        _zeroGovernor.setCashToken(address(0), 1e18);
    }

    /* ============ setEmergencyProposalQuorumNumerator ============ */
    function test_setEmergencyProposalQuorumNumerator() external {
        vm.expectCall(address(_emergencyGovernor), abi.encodeCall(_emergencyGovernor.setQuorumNumerator, (100)));

        vm.prank(address(_zeroGovernor));
        _zeroGovernor.setEmergencyProposalQuorumNumerator(100);
    }

    function test_setEmergencyProposalQuorumNumerator_notZeroGovernor() external {
        vm.expectRevert(IBatchGovernor.NotSelf.selector);
        _zeroGovernor.setEmergencyProposalQuorumNumerator(_emergencyProposalQuorumNumerator);
    }

    /* ============ setZeroProposalQuorumNumerator ============ */
    function test_setZeroProposalQuorumNumerator_notZeroGovernor() external {
        vm.expectRevert(IBatchGovernor.NotSelf.selector);
        _zeroGovernor.setZeroProposalQuorumNumerator(_zeroProposalQuorumNumerator);
    }

    function test_setZeroProposalQuorumNumerator_invalidQuorumNumeratorAboveOne() external {
        vm.prank(address(_zeroGovernor));

        vm.expectRevert(
            abi.encodeWithSelector(IThresholdGovernor.InvalidQuorumNumerator.selector, 10_001, 271, 10_000)
        );
        _zeroGovernor.setZeroProposalQuorumNumerator(10_001);
    }

    function test_setZeroProposalQuorumNumerator_invalidQuorumNumeratorBelowMin() external {
        vm.prank(address(_zeroGovernor));

        vm.expectRevert(abi.encodeWithSelector(IThresholdGovernor.InvalidQuorumNumerator.selector, 1, 271, 10_000));
        _zeroGovernor.setZeroProposalQuorumNumerator(1);
    }

    /* ============ revertIfInvalidCalldata ============ */
    function test_revertIfInvalidCalldata() external {
        vm.expectRevert(IBatchGovernor.InvalidCallData.selector);
        _zeroGovernor.revertIfInvalidCalldata(abi.encode("randomCalldata"));
    }

    function test_revertIfInvalidCalldata_resetToPowerHolders() external {
        vm.expectRevert(IBatchGovernor.InvalidCallData.selector);
        _zeroGovernor.revertIfInvalidCalldata(
            abi.encodePacked(abi.encodeWithSelector(_zeroGovernor.resetToPowerHolders.selector), "randomCalldata")
        );
    }

    function test_revertIfInvalidCalldata_resetToZeroHolders() external {
        vm.expectRevert(IBatchGovernor.InvalidCallData.selector);
        _zeroGovernor.revertIfInvalidCalldata(
            abi.encodePacked(abi.encodeWithSelector(_zeroGovernor.resetToZeroHolders.selector), "randomCalldata")
        );
    }

    function test_revertIfInvalidCalldata_setCashToken() external {
        vm.expectRevert(IBatchGovernor.InvalidCallData.selector);
        _zeroGovernor.revertIfInvalidCalldata(
            abi.encodePacked(abi.encodeCall(_zeroGovernor.setCashToken, (makeAddr("random"), 10)), "randomCalldata")
        );
    }

    function test_revertIfInvalidCalldata_setEmergencyProposalQuorumNumerator() external {
        vm.expectRevert(IBatchGovernor.InvalidCallData.selector);
        _zeroGovernor.revertIfInvalidCalldata(
            abi.encodePacked(
                abi.encodeCall(_zeroGovernor.setEmergencyProposalQuorumNumerator, (1000)),
                "randomCalldata"
            )
        );
    }

    function test_revertIfInvalidCalldata_setZeroProposalQuorumNumerator() external {
        vm.expectRevert(IBatchGovernor.InvalidCallData.selector);
        _zeroGovernor.revertIfInvalidCalldata(
            abi.encodePacked(abi.encodeCall(_zeroGovernor.setZeroProposalQuorumNumerator, (1000)), "randomCalldata")
        );
    }

    /* ============ castVote ============ */
    function test_castVote_proposalDoesNotExist() external {
        uint256 proposalId_ = 1;

        vm.expectRevert(abi.encodeWithSelector(IBatchGovernor.ProposalDoesNotExist.selector));

        _zeroGovernor.castVote(proposalId_, uint8(IBatchGovernor.VoteType.Yes));
    }
}
