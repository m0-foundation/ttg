// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import { IGovernanceDeployer } from "./IGovernanceDeployer.sol";

import { DualGovernor } from "../core/governor/DualGovernor.sol";
import { SPOGControlled } from "../periphery/SPOGControlled.sol";
import { VOTE } from "../tokens/VOTE.sol";

contract GovernanceDeployer is IGovernanceDeployer, SPOGControlled {
    address public governor;

    constructor(address spog_) SPOGControlled(spog_) {}

    function deployGovernance(
        bytes memory deployArguments
    ) external onlySPOG returns (address governor_, address vote) {
        (
            string memory voteName,
            string memory voteSymbol,
            string memory governorName,
            address value,
            uint256 voteQuorum,
            uint256 valueQuorum,
            bytes32 salt
        ) = abi.decode(deployArguments, (string, string, string, address, uint256, uint256, bytes32));

        (governor_, vote) = deployGovernance(voteName, voteSymbol, governorName, value, voteQuorum, valueQuorum, salt);
    }

    function deployGovernance(
        string memory voteName,
        string memory voteSymbol,
        string memory governorName,
        address value,
        uint256 voteQuorum,
        uint256 valueQuorum,
        bytes32 salt
    ) public onlySPOG returns (address governor_, address vote) {
        address expectedVote = getDeterministicVoteAddress(voteName, voteSymbol, value, salt);

        address expectedGovernor = getDeterministicGovernorAddress(
            governorName,
            expectedVote,
            value,
            voteQuorum,
            valueQuorum,
            salt
        );

        // Set public governor so that VOTE deployment cn access it during it's constructor.
        // NOTE: SPOG does not exist during its own constructor, so VOTE cannot read the expected governor from it.
        governor = expectedGovernor;

        vote = address(new VOTE{ salt: salt }(voteName, voteSymbol, spog, value));

        // Only needed this during the deployment of VOTE. Can be deleted so save gas.
        delete governor;

        if (vote != expectedVote) revert VoteAddressMismatch(vote, expectedVote);

        governor_ = address(new DualGovernor{ salt: salt }(governorName, vote, value, voteQuorum, valueQuorum, spog));

        if (governor_ != expectedGovernor) revert GovernorAddressMismatch(governor_, expectedGovernor);
    }

    function getGovernanceAddresses(
        bytes memory deployArguments
    ) external view returns (address governor_, address vote) {
        (
            string memory voteName,
            string memory voteSymbol,
            string memory governorName,
            address value,
            uint256 voteQuorum,
            uint256 valueQuorum,
            bytes32 salt
        ) = abi.decode(deployArguments, (string, string, string, address, uint256, uint256, bytes32));

        (governor_, vote) = getGovernanceAddresses(
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
    ) public view returns (address governor_, address vote) {
        vote = getDeterministicVoteAddress(voteName, voteSymbol, value, salt);

        governor_ = getDeterministicGovernorAddress(governorName, vote, value, voteQuorum, valueQuorum, salt);
    }

    /// @dev Returns the deterministic address of a proxy given some salt.
    function getDeterministicVoteAddress(
        string memory name,
        string memory symbol,
        address value,
        bytes32 salt
    ) public view returns (address deterministicAddress_) {
        // See https://docs.soliditylang.org/en/v0.8.7/control-structures.html#salted-contract-creations-create2
        deterministicAddress_ = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            address(this),
                            salt,
                            keccak256(abi.encodePacked(type(VOTE).creationCode, abi.encode(name, symbol, spog, value)))
                        )
                    )
                )
            )
        );
    }

    /// @dev Returns the deterministic address of a proxy given some salt.
    function getDeterministicGovernorAddress(
        string memory name,
        address vote,
        address value,
        uint256 voteQuorum,
        uint256 valueQuorum,
        bytes32 salt
    ) public view returns (address deterministicAddress_) {
        // See https://docs.soliditylang.org/en/v0.8.7/control-structures.html#salted-contract-creations-create2
        deterministicAddress_ = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            address(this),
                            salt,
                            keccak256(
                                abi.encodePacked(
                                    type(DualGovernor).creationCode,
                                    abi.encode(name, vote, value, voteQuorum, valueQuorum, spog)
                                )
                            )
                        )
                    )
                )
            )
        );
    }
}
