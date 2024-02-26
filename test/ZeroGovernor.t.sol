// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { IThresholdGovernor } from "../src/abstract/interfaces/IThresholdGovernor.sol";
import { IBatchGovernor } from "../src/abstract/interfaces/IBatchGovernor.sol";
import { IStandardGovernor } from "../src/interfaces/IStandardGovernor.sol";
import { IZeroGovernor } from "../src/interfaces/IZeroGovernor.sol";

import { MockBootstrapToken, MockEmergencyGovernor, MockEmergencyGovernorDeployer } from "./utils/Mocks.sol";
import { MockPowerTokenDeployer, MockStandardGovernor, MockStandardGovernorDeployer } from "./utils/Mocks.sol";
import { TestUtils } from "./utils/TestUtils.sol";
import { ZeroGovernorHarness } from "./utils/ZeroGovernorHarness.sol";

contract ZeroGovernorTests is TestUtils {
    address internal _cashToken1 = makeAddr("cashToken1");
    address internal _cashToken2 = makeAddr("cashToken2");

    uint16 internal _emergencyProposalThresholdRatio = 9_000; // 90%
    uint16 internal _zeroProposalThresholdRatio = 6_000; // 60%

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

        _emergencyGovernor.setThresholdRatio(1);
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
            _zeroProposalThresholdRatio,
            _allowedCashTokens
        );

        _standardGovernorDeployer.setLastDeploy(address(_standardGovernor));

        _emergencyGovernorDeployer.setLastDeploy(address(_emergencyGovernor));
    }

    function test_initialState() external {
        assertEq(_zeroGovernor.voteToken(), address(_zeroToken));
        assertEq(_zeroGovernor.emergencyGovernorDeployer(), address(_emergencyGovernorDeployer));
        assertEq(_zeroGovernor.powerTokenDeployer(), address(_powerTokenDeployer));
        assertEq(_zeroGovernor.standardGovernorDeployer(), address(_standardGovernorDeployer));
        assertEq(_zeroGovernor.thresholdRatio(), _zeroProposalThresholdRatio);
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
            _zeroProposalThresholdRatio,
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
            _zeroProposalThresholdRatio,
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
            _zeroProposalThresholdRatio,
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
            _zeroProposalThresholdRatio,
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
            _zeroProposalThresholdRatio,
            new address[](1)
        );
    }

    /* ============ getProposal ============ */
    function test_getProposal_proposalDoesNotExist() external {
        vm.expectRevert(IBatchGovernor.ProposalDoesNotExist.selector);
        _zeroGovernor.getProposal(0);
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

    /* ============ setEmergencyProposalThresholdRatio ============ */
    function test_setEmergencyProposalThresholdRatio() external {
        vm.expectCall(address(_emergencyGovernor), abi.encodeCall(_emergencyGovernor.setThresholdRatio, (100)));

        vm.prank(address(_zeroGovernor));
        _zeroGovernor.setEmergencyProposalThresholdRatio(100);
    }

    function test_setEmergencyProposalThresholdRatio_notZeroGovernor() external {
        vm.expectRevert(IBatchGovernor.NotSelf.selector);
        _zeroGovernor.setEmergencyProposalThresholdRatio(_emergencyProposalThresholdRatio);
    }

    /* ============ setZeroProposalThresholdRatio ============ */
    function test_setZeroProposalThresholdRatio_notZeroGovernor() external {
        vm.expectRevert(IBatchGovernor.NotSelf.selector);
        _zeroGovernor.setZeroProposalThresholdRatio(_zeroProposalThresholdRatio);
    }

    function test_setZeroProposalThresholdRatio_invalidThresholdRatioAboveOne() external {
        vm.prank(address(_zeroGovernor));

        vm.expectRevert(abi.encodeWithSelector(IThresholdGovernor.InvalidThresholdRatio.selector, 10_001, 271, 10_000));
        _zeroGovernor.setZeroProposalThresholdRatio(10_001);
    }

    function test_setZeroProposalThresholdRatio_invalidThresholdRatioBelowMin() external {
        vm.prank(address(_zeroGovernor));

        vm.expectRevert(abi.encodeWithSelector(IThresholdGovernor.InvalidThresholdRatio.selector, 1, 271, 10_000));
        _zeroGovernor.setZeroProposalThresholdRatio(1);
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

    function test_revertIfInvalidCalldata_setEmergencyProposalThresholdRatio() external {
        vm.expectRevert(IBatchGovernor.InvalidCallData.selector);
        _zeroGovernor.revertIfInvalidCalldata(
            abi.encodePacked(abi.encodeCall(_zeroGovernor.setEmergencyProposalThresholdRatio, (1000)), "randomCalldata")
        );
    }

    function test_revertIfInvalidCalldata_setZeroProposalThresholdRatio() external {
        vm.expectRevert(IBatchGovernor.InvalidCallData.selector);
        _zeroGovernor.revertIfInvalidCalldata(
            abi.encodePacked(abi.encodeCall(_zeroGovernor.setZeroProposalThresholdRatio, (1000)), "randomCalldata")
        );
    }

    /* ============ castVote ============ */
    function test_castVote_proposalDoesNotExist() external {
        uint256 proposalId_ = 1;

        vm.expectRevert(abi.encodeWithSelector(IBatchGovernor.ProposalDoesNotExist.selector));

        _zeroGovernor.castVote(proposalId_, uint8(IBatchGovernor.VoteType.Yes));
    }
}
