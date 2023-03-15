// SPDX-License-Identifier: MIT

pragma solidity >=0.8.19;

import { ERC721 } from "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import { Ownable } from "openzeppelin-contracts/contracts/access/Ownable.sol";
import { MerkleProof } from "openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";
import { Strings } from "openzeppelin-contracts/contracts/utils/Strings.sol";
import { Pausable } from "openzeppelin-contracts/contracts/security/Pausable.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { AggregatorV3Interface } from "src/interfaces/AggregatorV3Interface.sol";

contract InsureABag is ERC721, Ownable, Pausable {
    using Strings for uint256;

    event PolicyCreated(uint256 policyId, address collectionAddress, uint256 tokenId, uint256 expiryTime);

    AggregatorV3Interface internal apeEth;
    IERC20 internal apeCoin;
    uint256 private currentIndex;
    address public vaultAddress;
    string public baseURI;
    string public uriExtension;
    bytes32 public collectionsMerkleRoot;

    error NonexistentToken();
    error TokenAlreadyRegistered();
    error IsZeroAddress();
    error UnsupportedCollection();
    error InvalidDuration();
    error NotOwnerNorApproved();

    mapping(address useraddress => mapping(address contractAddress => mapping(uint256 tokenId => uint256 expiry)))
        internal _currentUsers;

    constructor(string memory name_, string memory symbol_, address _apeCoin, address _apeEth) ERC721(name_, symbol_) {
        apeCoin = IERC20(_apeCoin);
        apeEth = AggregatorV3Interface(_apeEth);
    }

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
        if (_currentUsers[msg.sender][_contractAddress][_tokenId] != 0) {
            revert TokenAlreadyRegistered();
        }
        uint256 expiryTimestamp = _getCurrentBlockstamp() + (_duration * 1 days);
        _currentUsers[msg.sender][_contractAddress][_tokenId] = expiryTimestamp;
        currentIndex += 1;
        _safeMint(msg.sender, currentIndex);
        emit PolicyCreated(currentIndex, _contractAddress, _tokenId, expiryTimestamp);
    }

    /// @notice renew a existing policy
    /// @param _contractAddress the address of the collection
    /// @param _tokenId the id of the token
    /// @param _duration the duration of the policy
    function renewPolicy(
        uint256 _policyId,
        address _contractAddress,
        uint256 _tokenId,
        uint64 _duration
    )
        external
        payable
    {
        if (!_isApprovedOrOwner(msg.sender, _policyId)) revert NotOwnerNorApproved();
        if (!isMultipleOfMonth(_duration)) revert InvalidDuration();
        uint256 expiryTime = _currentUsers[msg.sender][_contractAddress][_tokenId];
        if (_getCurrentBlockstamp() > expiryTime) {
            _currentUsers[msg.sender][_contractAddress][_tokenId] = _getCurrentBlockstamp() + (_duration * 1 days);
        } else if (_getCurrentBlockstamp() < expiryTime) {
            _currentUsers[msg.sender][_contractAddress][_tokenId] = expiryTime + (_duration * 1 days);
        }
    }

    /// @notice cancel the insurance Policy
    /// @param _contractAddress the address of the collection
    /// @param _tokenId the id of the token
    function cancelSubscription(uint256 _policyId, address _contractAddress, uint256 _tokenId) external {
        if (!_isApprovedOrOwner(msg.sender, _tokenId)) revert NotOwnerNorApproved();
        delete _currentUsers[msg.sender][_contractAddress][_tokenId];
        _burn(_policyId);
    }

    function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
        if (!_exists(_tokenId)) revert NonexistentToken();
        return string(abi.encodePacked(baseURI, _tokenId.toString(), uriExtension));
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

    /// @notice return the expiry timestamp of policy
    /// @param _userAddress of the policy holder
    /// @param _collectionAddress the address of the collection
    /// @param _tokenId the insured tokenId
    function getExpiryTimestamp(
        address _userAddress,
        address _collectionAddress,
        uint256 _tokenId
    )
        external
        view
        returns (uint256)
    {
        return _currentUsers[_userAddress][_collectionAddress][_tokenId];
    }

    /// @notice return true if policy has expired
    /// @param _userAddress of the policy holder
    /// @param _collectionAddress the address of the collection
    /// @param _tokenId the insured tokenId
    function _isExpired(
        address _userAddress,
        address _collectionAddress,
        uint256 _tokenId
    )
        external
        view
        returns (bool)
    {
        return _currentUsers[_userAddress][_collectionAddress][_tokenId] < _getCurrentBlockstamp();
    }

    /// @notice returns the current block timestamp
    /// @return the current block timestamp
    function _getCurrentBlockstamp() internal view returns (uint256) {
        return block.timestamp;
    }

    /// @notice checks if the duration is a multiple of a month
    function isMultipleOfMonth(uint256 _duration) public pure returns (bool) {
        uint256 oneMonth = 30;
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
        uriExtension = _uriExtension;
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
