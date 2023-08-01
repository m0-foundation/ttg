// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import { IGovernanceDeployer } from "./IGovernanceDeployer.sol";
import { IGovernorDeployer } from "./IGovernorDeployer.sol";
import { IVoteDeployer } from "./IVoteDeployer.sol";

import { ControlledByComptroller } from "../comptroller/ControlledByComptroller.sol";

contract GovernanceDeployer is IGovernanceDeployer, ControlledByComptroller {
    address public immutable governorDeployer;
    address public immutable voteDeployer;

    constructor(
        address comptroller_,
        address governorDeployer_,
        address voteDeployer_
    ) ControlledByComptroller(comptroller_) {
        governorDeployer = governorDeployer_;
        voteDeployer = voteDeployer_;
    }

    function deployGovernance(
        bytes memory deployArguments
    ) external onlyComptroller returns (address governor_, address vote_) {
        (
            string memory voteName,
            string memory voteSymbol,
            string memory governorName,
            address value,
            uint256 voteQuorum,
            uint256 valueQuorum,
            bytes32 salt
        ) = abi.decode(deployArguments, (string, string, string, address, uint256, uint256, bytes32));

        (governor_, vote_) = deployGovernance(voteName, voteSymbol, governorName, value, voteQuorum, valueQuorum, salt);
    }

    function deployGovernance(
        string memory voteName,
        string memory voteSymbol,
        string memory governorName,
        address value,
        uint256 voteQuorum,
        uint256 valueQuorum,
        bytes32 salt
    ) public onlyComptroller returns (address governor_, address vote_) {
        (address expectedGovernor, address expectedVote) = getGovernanceAddresses(
            voteName,
            voteSymbol,
            governorName,
            value,
            voteQuorum,
            valueQuorum,
            salt
        );

        vote_ = IVoteDeployer(voteDeployer).deployVote(
            voteName,
            voteSymbol,
            comptroller,
            value,
            expectedGovernor,
            salt
        );

        if (vote_ != expectedVote) revert VoteAddressMismatch(vote_, expectedVote);

        governor_ = IGovernorDeployer(governorDeployer).deployGovernor(
            governorName,
            vote_,
            value,
            voteQuorum,
            valueQuorum,
            comptroller,
            salt
        );

        if (governor_ != expectedGovernor) revert GovernorAddressMismatch(governor_, expectedGovernor);
    }

    function getGovernanceAddresses(
        bytes memory deployArguments
    ) external view returns (address governor_, address vote_) {
        (
            string memory voteName,
            string memory voteSymbol,
            string memory governorName,
            address value,
            uint256 voteQuorum,
            uint256 valueQuorum,
            bytes32 salt
        ) = abi.decode(deployArguments, (string, string, string, address, uint256, uint256, bytes32));

        (governor_, vote_) = getGovernanceAddresses(
            voteName,
            voteSymbol,
            governorName,
            value,
            voteQuorum,
            valueQuorum,
            salt
        );
    }

    function getGovernanceAddresses(
        string memory voteName,
        string memory voteSymbol,
        string memory governorName,
        address value,
        uint256 voteQuorum,
        uint256 valueQuorum,
        bytes32 salt
    ) public view returns (address governor_, address vote_) {
        vote_ = IVoteDeployer(voteDeployer).getDeterministicVoteAddress(voteName, voteSymbol, comptroller, value, salt);

        governor_ = IGovernorDeployer(governorDeployer).getDeterministicGovernorAddress(
            governorName,
            vote_,
            value,
            voteQuorum,
            valueQuorum,
            comptroller,
            salt
        );
    }
}
