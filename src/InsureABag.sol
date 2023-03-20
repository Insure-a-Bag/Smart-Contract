// SPDX-License-Identifier: MIT

pragma solidity >=0.8.19;

import { ERC721 } from "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import { Ownable } from "openzeppelin-contracts/contracts/access/Ownable.sol";
import { MerkleProof } from "openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";
import { Strings } from "openzeppelin-contracts/contracts/utils/Strings.sol";
import { SafeMath } from "openzeppelin-contracts/contracts/utils/math/SafeMath.sol";
import { Pausable } from "openzeppelin-contracts/contracts/security/Pausable.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IERC721 } from "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import { AggregatorV3Interface } from "src/interfaces/AggregatorV3Interface.sol";
import { Counters } from "openzeppelin-contracts/contracts/utils/Counters.sol";

contract InsureABag is ERC721, Ownable, Pausable {
    using Strings for uint256;
    using Counters for Counters.Counter;

    event PolicyCreated(uint256 policyId, address collectionAddress, uint256 tokenId, uint256 expiryTime);

    AggregatorV3Interface internal apeEth;
    IERC20 internal apeCoin;
    Counters.Counter private _tokenIds;
    uint256 internal maxRate;
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
    error InsufficientFunds();
    error InvalidWithdrawalAmount();
    error NotNFTOwner();

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
        whenNotPaused
    {
        if (!_isMultipleOfMonth(_duration)) revert InvalidDuration();
        if (!isCollectionAddressSupported(_contractAddress, _proof)) revert UnsupportedCollection();
        if (_currentUsers[msg.sender][_contractAddress][_tokenId] != 0) {
            revert TokenAlreadyRegistered();
        }
        if (msg.sender != IERC721(_contractAddress).ownerOf(_tokenId)) revert NotNFTOwner();
        if (msg.value < _getCostETH(_duration)) revert InsufficientFunds();
        uint256 expiryTimestamp = _getCurrentBlockstamp() + (_duration * 1 days);
        _currentUsers[msg.sender][_contractAddress][_tokenId] = expiryTimestamp;
        _tokenIds.increment();
        _safeMint(msg.sender, _tokenIds.current());
        emit PolicyCreated(_tokenIds.current(), _contractAddress, _tokenId, expiryTimestamp);
    }

    /// @notice mint a new policy
    /// @param _contractAddress the address of the collection
    /// @param _tokenId the id of the token
    /// @param _proof the merkle proof
    /// @param _duration the duration of the policy
    function mintInsurancePolicyApe(
        address _contractAddress,
        uint256 _tokenId,
        bytes32[] calldata _proof,
        uint256 _duration
    )
        external
        payable
        whenNotPaused
    {
        if (!_isMultipleOfMonth(_duration)) revert InvalidDuration();
        if (!isCollectionAddressSupported(_contractAddress, _proof)) revert UnsupportedCollection();
        if (_currentUsers[msg.sender][_contractAddress][_tokenId] != 0) {
            revert TokenAlreadyRegistered();
        }
        if (msg.sender != IERC721(_contractAddress).ownerOf(_tokenId)) revert NotNFTOwner();
        if (apeCoin.balanceOf(msg.sender) < _getCostApe(_duration)) revert InsufficientFunds();
        apeCoin.transferFrom(msg.sender, address(this), _getCostApe(_duration));
        uint256 expiryTimestamp = _getCurrentBlockstamp() + (_duration * 1 days);
        _currentUsers[msg.sender][_contractAddress][_tokenId] = expiryTimestamp;
        _tokenIds.increment();
        _safeMint(msg.sender, _tokenIds.current());
        emit PolicyCreated(_tokenIds.current(), _contractAddress, _tokenId, expiryTimestamp);
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
        whenNotPaused
    {
        if (!_isApprovedOrOwner(msg.sender, _policyId)) revert NotOwnerNorApproved();
        if (!_isMultipleOfMonth(_duration)) revert InvalidDuration();
        if (msg.sender != IERC721(_contractAddress).ownerOf(_tokenId)) revert NotNFTOwner();
        if (msg.value < _getCostETH(_duration)) revert InsufficientFunds();
        uint256 expiryTime = _currentUsers[msg.sender][_contractAddress][_tokenId];
        if (_getCurrentBlockstamp() > expiryTime) {
            _currentUsers[msg.sender][_contractAddress][_tokenId] = _getCurrentBlockstamp() + (_duration * 1 days);
        } else if (_getCurrentBlockstamp() < expiryTime) {
            _currentUsers[msg.sender][_contractAddress][_tokenId] = expiryTime + (_duration * 1 days);
        }
    }

    /// @notice renew a existing policy
    /// @param _contractAddress the address of the collection
    /// @param _tokenId the id of the token
    /// @param _duration the duration of the policy
    function renewPolicyApe(
        uint256 _policyId,
        address _contractAddress,
        uint256 _tokenId,
        uint64 _duration
    )
        external
        payable
        whenNotPaused
    {
        if (!_isApprovedOrOwner(msg.sender, _policyId)) revert NotOwnerNorApproved();
        if (!_isMultipleOfMonth(_duration)) revert InvalidDuration();
        if (msg.sender != IERC721(_contractAddress).ownerOf(_tokenId)) revert NotNFTOwner();
        if (apeCoin.balanceOf(msg.sender) < _getCostApe(_duration)) revert InsufficientFunds();
        apeCoin.transferFrom(msg.sender, address(this), _getCostApe(_duration));
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

    /// @notice obtain the current APE/ETH rate
    function getApeEthRate() internal view returns (uint256) {
        (, int256 price,,,) = apeEth.latestRoundData();
        return uint256(price);
    }

    /// @notice obtains the floor price of collection
    /// Needs to be incorporated with oracle
    function _getFloorPrice() internal pure returns (uint256) {
        return 0.01 ether;
    }

    /// @notice multiplies ETH cost per month by number of months
    function _getCostETH(uint256 _duration) internal view returns (uint256) {
        uint256 durationInMonths = _duration.div(30);
        uint256 usedRate = getRate(_duration);
        uint256 rateTimesDuration = usedRate.mul(durationInMonths);
        return _getFloorPrice().mul(rateTimesDuration).div(10_000);
    }

    /// @notice multiplies Ape cost per month by number of months
    /// @param _duration the duration in months
    function _getCostApe(uint256 _duration) internal view returns (uint256) {
        uint256 floorPriceApe = _getFloorPrice().div(getApeEthRate());
        uint256 durationInMonths = _duration.div(30);
        uint256 usedRate = getRate(_duration);
        uint256 rateTimesDuration = usedRate.mul(durationInMonths);
        return floorPriceApe.mul(rateTimesDuration).div(10_000);
    }

    /// @notice calculate a progressive rate
    /// @param _duration the duration in months
    function getRate(uint256 _duration) internal view returns (uint256) {
        uint256 usedRate;
        if (_duration >= 180 && _duration < 360) {
            usedRate = maxRate.mul(70).div(100);
        } else if (_duration >= 360 && _duration < 540) {
            usedRate = maxRate.mul(50).div(100);
        } else if (_duration >= 540) {
            usedRate = maxRate.mul(30).div(100);
        } else {
            usedRate = maxRate;
        }
        return usedRate;
    }

    /// @notice checks if the duration is a multiple of a month
    /// @param _duration the duration in months
    function _isMultipleOfMonth(uint256 _duration) internal pure returns (bool) {
        uint256 oneMonth = 30;
        return _duration % oneMonth == 0;
    }

    /// @notice sets the vault address
    /// @param _vaultAddress the address of the vault contract
    function setVaultAddress(address _vaultAddress) external onlyOwner {
        if (_vaultAddress == address(0)) revert IsZeroAddress();
        vaultAddress = _vaultAddress;
    }

    /// @notice sets the vault address
    /// @param _rate the percent of floor price charged per month
    function setRate(uint256 _rate) external onlyOwner {
        maxRate = _rate;
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

    /// @notice withdraw funds
    function withdrawToVault(uint256 _amount) external onlyOwner {
        if (_amount > address(this).balance) revert InvalidWithdrawalAmount();
        (bool success,) = vaultAddress.call{ value: _amount }("");
        require(success, "Failed to withdraw");
    }
}
