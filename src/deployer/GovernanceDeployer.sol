// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import { IGovernanceDeployer } from "./IGovernanceDeployer.sol";
import { IGovernorDeployer } from "./IGovernorDeployer.sol";
import { IVoteDeployer } from "./IVoteDeployer.sol";

import { SPOGControlled } from "../periphery/SPOGControlled.sol";

contract GovernanceDeployer is IGovernanceDeployer, SPOGControlled {
    address public immutable governorDeployer;
    address public immutable voteDeployer;

    constructor(address spog_, address governorDeployer_, address voteDeployer_) SPOGControlled(spog_) {
        governorDeployer = governorDeployer_;
        voteDeployer = voteDeployer_;
    }

    function deployGovernance(
        bytes memory deployArguments
    ) external onlySPOG returns (address governor_, address vote_) {
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
    ) public onlySPOG returns (address governor_, address vote_) {
        (address expectedGovernor, address expectedVote) = getGovernanceAddresses(
            voteName,
            voteSymbol,
            governorName,
            value,
            voteQuorum,
            valueQuorum,
            salt
        );

        vote_ = IVoteDeployer(voteDeployer).deployVote(voteName, voteSymbol, spog, value, expectedGovernor, salt);

        if (vote_ != expectedVote) revert VoteAddressMismatch(vote_, expectedVote);

        governor_ = IGovernorDeployer(governorDeployer).deployGovernor(
            governorName,
            vote_,
            value,
            voteQuorum,
            valueQuorum,
            spog,
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
        vote_ = IVoteDeployer(voteDeployer).getDeterministicVoteAddress(voteName, voteSymbol, spog, value, salt);

        governor_ = IGovernorDeployer(governorDeployer).getDeterministicGovernorAddress(
            governorName,
            vote_,
            value,
            voteQuorum,
            valueQuorum,
            spog,
            salt
        );
    }
}
