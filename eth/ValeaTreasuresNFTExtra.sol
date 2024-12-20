// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

error vlaNFT__NotOwner();
error vlaNFT__InvalidRoyaltyPercentage();

contract ValeaTreasuresNFTExtra {
    //// ERC 165 : INTERFACES

    //// ERC173 Ownership

    // The owner of the contract.
    address internal _owner;

    // Modifier to make a function callable only by the owner.
    modifier onlyOwner() {
        if (msg.sender != _owner) {
            revert vlaNFT__NotOwner();
        }
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     * @return The address of the owner.
     */
    function owner() external view returns (address) {
        return _owner;
    }

    /**
     * @dev Transfers ownership of the contract to a new address.
     * Can only be called by the current owner.
     * @param newOwner The address of the new owner.
     */
    function transferOwnership(address newOwner) external onlyOwner {
        _owner = newOwner;
    }

    //// IERC-2981 Royalty
    // The royalty percentage for the token. In INT type from 0-100
    uint8 private _royaltyPercentage = 1;

    /**
     * @dev Provides the royalty information for a token.
     * @param _tokenId The id of the token.
     * @param _salePrice The sale price of the token.
     * @return receiver The receiver of the royalties.
     * @return royaltyAmount The amount of royalties.
     */
    function royaltyInfo(
        uint256 _tokenId,
        uint256 _salePrice
    ) external view returns (address receiver, uint256 royaltyAmount) {
        if (false) _tokenId;
        return (_owner, (_salePrice * _royaltyPercentage) / 100);
    }

    /**
     * @dev Returns the royalty percentage for a token as a 0-100 percent
     * @return The royalty percentage.
     */
    function getRoyaltyPercentage() external view returns (uint8) {
        return _royaltyPercentage;
    }

    /**
     * @dev Sets the royalty percentage for a token.
     * Can only be called by the current owner.
     * @param percentage The new royalty percentage.
     * From 0 to 100
     */
    function setRoyaltyPercentage(uint8 percentage) external onlyOwner {
        if (percentage > 100) {
            revert vlaNFT__InvalidRoyaltyPercentage();
        }
        _royaltyPercentage = percentage;
    }
}
