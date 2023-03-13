// SPDX-License-Identifier: MIT

pragma solidity >=0.8.19;

import { ERC5643 } from "src/ERC5643.sol";
import { Ownable } from "openzeppelin-contracts/contracts/access/Ownable.sol";
import { MerkleProof } from "openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";
import { Strings } from "openzeppelin-contracts/contracts/utils/Strings.sol";
import { Pausable } from "openzeppelin-contracts/contracts/security/Pausable.sol";

contract InsureABag is ERC5643, Ownable, Pausable {
    using Strings for uint256;

    enum ExpiryDuration {
        Year,
        TwoYears,
        ThreeYears
    }

    struct PolicyInfo {
        uint256 insuredTokenId;
        uint256 expiresTimestamp;
    }

    uint256 private currentIndex;
    address public vaultAddress;
    string public baseURI;
    string public URIExtension;
    bytes32 public collectionsMerkleRoot;

    error NonexistentToken();
    error TokenAlreadyInsured();
    error IsZeroAddress();
    error UnsupportedCollection();
    error InvalidDuration();

    mapping(address => mapping(address => PolicyInfo)) internal _currentUsers;

    constructor(string memory name_, string memory symbol_) ERC5643(name_, symbol_) { }

    /// @notice mint a new policy
    /// @param _contractAddress the address of the collection
    /// @param _tokenId the id of the token
    /// @param _proof the merkle proof
    /// @param _duration the duration of the policy
    function mintInsurancePolicy(
        address _contractAddress,
        uint256 _tokenId,
        bytes32[] calldata _proof,
        uint256 _duration
    )
        external
        payable
    {
        if (!isMultipleOfMonth(_duration)) revert InvalidDuration();
        if (!isCollectionAddressSupported(_contractAddress, _proof)) revert UnsupportedCollection();
        if (_currentUsers[msg.sender][_contractAddress].insuredTokenId == _tokenId) revert TokenAlreadyInsured();

        PolicyInfo memory newPolicy =
            PolicyInfo({ insuredTokenId: _tokenId, expiresTimestamp: getCurrentBlockstamp() + _duration });
        _currentUsers[msg.sender][_contractAddress] = newPolicy;
        currentIndex += 1;
        _safeMint(msg.sender, currentIndex);
    }

    function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
        if (!_exists(_tokenId)) revert NonexistentToken();
        return string(abi.encodePacked(baseURI, _tokenId.toString(), URIExtension));
    }

    function setCollectionsMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        collectionsMerkleRoot = _merkleRoot;
    }

    function leaf(address _contractAddress) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_contractAddress));
    }

    function _verifyAddress(bytes32 _leaf, bytes32[] memory _proof) internal view returns (bool) {
        return MerkleProof.verify(_proof, collectionsMerkleRoot, _leaf);
    }

    /// @notice checks if the collection is supported
    /// @param _contractAddress the address of the collection
    /// @param _proof the merkle proof
    function isCollectionAddressSupported(
        address _contractAddress,
        bytes32[] calldata _proof
    )
        internal
        view
        returns (bool)
    {
        return _verifyAddress(leaf(_contractAddress), _proof);
    }

    /// @notice returns the current block timestamp
    /// @return the current block timestamp
    function getCurrentBlockstamp() internal view returns (uint256) {
        return block.timestamp;
    }

    /// @notice checks if the duration is a multiple of a month
    function isMultipleOfMonth(uint256 _duration) public pure returns (bool) {
        uint256 oneMonth = 30 days;
        return _duration % oneMonth == 0;
    }

    /// @notice sets the vault address
    /// @param _vaultAddress the address of the vault contract
    function setVaultAddress(address _vaultAddress) external onlyOwner {
        if (_vaultAddress == address(0)) revert IsZeroAddress();
        vaultAddress = _vaultAddress;
    }

    /// @notice sets the uri for the token metadata
    /// @param _baseURI the base URI for the token metadata
    function setBaseURI(string memory _baseURI) external onlyOwner {
        baseURI = _baseURI;
    }

    /// @notice sets the uri extension for the token metadata
    /// @param _uriExtension the URI extension for the token metadata
    function setURIExtension(string memory _uriExtension) external onlyOwner {
        URIExtension = _uriExtension;
    }

    /// @notice pauses the contract
    function pauseContract() external onlyOwner {
        _pause();
    }

    /// @notice unpauses the contract
    function unpauseContract() external onlyOwner {
        _unpause();
    }
}
