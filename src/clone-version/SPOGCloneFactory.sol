// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import {ERC165CheckerSPOG} from "src/ERC165CheckerSPOG.sol";
import {ISPOGClone} from "./ISPOGClone.sol";

/**
 * @title SPOGCloneFactory
 *
 * SPOG is created using a deterministic clone
 * of a default SPOG implementation  and initialized with arbitrary setup
 */
contract SPOGCloneFactory is Ownable, Pausable, ERC165CheckerSPOG {
    address public spog;
    address public spogToken;

    event SPOGCreated(address indexed spog, bytes32 salt);

    event SPOGCloneFactoryImplementationsSet(
        address indexed spog,
        address spogToken
    );

    /**
     * Configure factory with owner and set default guard contracts
     * @param owner_ Address to make the factory owner
     * @param spog_ Address of the deployed ERC721Collective
     * token to be cloned
     * @param spogToken_ Address of spogToken
     */
    constructor(
        address owner_,
        address spog_,
        address spogToken_
    ) Ownable() Pausable() {
        setImplementations(spog_, spogToken_);
        transferOwnership(owner_);
    }

    /// Predict spog token address for given salt
    /// @param salt Salt for determinisitic clone
    /// @return spogAddress Address of SPOG created with salt
    function predictAddress(bytes32 salt) external view returns (address) {
        return Clones.predictDeterministicAddress(spog, salt);
    }

    /**
     * Create a new SPOG via Clone
     * @param _cash The currency accepted for tax payment in the SPOG (must be ERC20)
     * @param _taxRange The minimum and maximum value of `tax`
     * @param _inflator The percentage supply increase in $VOTE for each voting epoch
     * @param _reward The number of $VALUE to be distributed in each voting epoch
     * @param _voteTime The duration of a voting epoch
     * @param _inflatorTime The duration of an auction if $VOTE is inflated (should be less than `VOTE TIME`)
     * @param _sellTime The duration of an auction if `SELL` is called
     * @param _forkTime The duration that $VALUE holders have to choose a fork
     * @param _voteQuorum The fraction of the current $VOTE supply voting "YES" for actions that require a `VOTE QUORUM`
     * @param _valueQuorum The fraction of the current $VALUE supply voting "YES" required for actions that require a `VALUE QUORUM`
     * @param _tax The cost (in `cash`) to call various functions
     * @return _spog Address of new SPOG
     */
    function create(
        address _cash,
        uint256[2] memory _taxRange,
        uint256 _inflator,
        uint256 _reward,
        uint256 _voteTime,
        uint256 _inflatorTime,
        uint256 _sellTime,
        uint256 _forkTime,
        uint256 _voteQuorum,
        uint256 _valueQuorum,
        uint256 _tax,
        bytes32 salt
    ) external whenNotPaused returns (address _spog) {
        _spog = _clone(
            _cash,
            _taxRange,
            _inflator,
            _reward,
            _voteTime,
            _inflatorTime,
            _sellTime,
            _forkTime,
            _voteQuorum,
            _valueQuorum,
            _tax,
            salt
        );
    }

    /**
     * internal function to clone new SPOG
     */
    function _clone(
        address _cash,
        uint256[2] memory _taxRange,
        uint256 _inflator,
        uint256 _reward,
        uint256 _voteTime,
        uint256 _inflatorTime,
        uint256 _sellTime,
        uint256 _forkTime,
        uint256 _voteQuorum,
        uint256 _valueQuorum,
        uint256 _tax,
        bytes32 salt
    ) internal whenNotPaused returns (address _spog) {
        _spog = Clones.cloneDeterministic(spog, salt);

        ISPOGClone(_spog).__SPOG_init(
            _cash,
            _taxRange,
            _inflator,
            _reward,
            _voteTime,
            _inflatorTime,
            _sellTime,
            _forkTime,
            _voteQuorum,
            _valueQuorum,
            _tax,
            spogToken
        );

        emit SPOGCreated(_spog, salt);
    }

    /**
     * Set implementation addresses.
     *
     * Requirements:
     * - Only the owner can call this function.
     * - The `spog_` to clone must implement ISPOGClone.
     * - The guards and renderer cannot be address 0.
     * @param spog_ Address of the deployed SPOG. It is the implementation to be cloned
     * @param spogToken_ Address of the spogToken implementation
     */
    function setImplementations(address spog_, address spogToken_)
        public
        onlyOwner
        onlySPOGInterface(spog_)
    {
        require(
            spog_ != address(0) && spogToken_ != address(0),
            "SPOGCloneFactory: implementations cannot be address(0)"
        );

        spog = spog_;
        spogToken = spogToken_;

        emit SPOGCloneFactoryImplementationsSet(spog, spogToken);
    }

    /**
     * Triggers paused state. Only accessible by the owner.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * Returns to normal state. Only accessible by the owner.
     */
    function unpause() external onlyOwner {
        _unpause();
    }
}
