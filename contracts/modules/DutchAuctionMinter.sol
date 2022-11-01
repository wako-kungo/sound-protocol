// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { IERC165 } from "openzeppelin/utils/introspection/IERC165.sol";
import { Math } from "openzeppelin/utils/math/Math.sol";
import { ISoundFeeRegistry } from "@core/interfaces/ISoundFeeRegistry.sol";
import { IDutchAuctionMinter, EditionMintData, MintInfo } from "./interfaces/IDutchAuctionMinter.sol";
import { BaseMinter } from "./BaseMinter.sol";
import { IMinterModule } from "@core/interfaces/IMinterModule.sol";
import { ISoundEditionV1, EditionInfo } from "@core/interfaces/ISoundEditionV1.sol";

/*
 * @title DutchAuctionMinter
 * @notice Module for Dutch Auction based mints of Sound editions. Based on the @divergencetech/ethier libarary's LinearDutchAuction.sol contract.
 * @author wakokungo.com
 */
contract DutchAuctionMinter is IDutchAuctionMinter, BaseMinter {
    // =============================================================
    //                            STORAGE
    // =============================================================

    /**
     * @dev Edition mint data
     * edition => mintId => EditionMintData
     */
    mapping(address => mapping(uint128 => EditionMintData)) internal _editionMintData;

    // =============================================================
    //                          CONSTRUCTOR
    // =============================================================

    constructor(ISoundFeeRegistry feeRegistry_) BaseMinter(feeRegistry_) {}

    // =============================================================
    //               PUBLIC / EXTERNAL WRITE FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc IDutchAuctionMinter
     */
    function createEditionMint(
        address edition,
        uint96 startPrice,
        uint32 startTime,
        uint32 decreaseInterval,
        uint96 decreaseSize,
        uint32 numDecreases,
        uint32 endTime,
        uint16 affiliateFeeBPS,
        uint32 maxMintable,
        uint32 maxMintablePerAccount
    ) public returns (uint128 mintId) {
        if (maxMintablePerAccount == 0) revert MaxMintablePerAccountIsZero();

        mintId = _createEditionMint(edition, startTime, endTime, affiliateFeeBPS);

        EditionMintData storage data = _editionMintData[edition][mintId];
        data.startPrice = startPrice;
        data.decreaseInterval = decreaseInterval;
        data.decreaseSize = decreaseSize;
        data.numDecreases = numDecreases;
        data.maxMintable = maxMintable;
        data.maxMintablePerAccount = maxMintablePerAccount;

        // prettier-ignore
        emit DutchAuctionMintCreated(
            edition,
            mintId,
            startPrice,
            startTime,
            decreaseInterval,
            decreaseSize,
            numDecreases,
            endTime,
            affiliateFeeBPS,
            maxMintable,
            maxMintablePerAccount
        );
    }

    /**
     * @inheritdoc IDutchAuctionMinter
     */
    function mint(
        address edition,
        uint128 mintId,
        uint32 quantity,
        address affiliate
    ) public payable {
        EditionMintData storage data = _editionMintData[edition][mintId];

        unchecked {
            // Check the additional `requestedQuantity` does not exceed the maximum mintable per account.
            uint256 numberMinted = ISoundEditionV1(edition).numberMinted(msg.sender);
            // Won't overflow. The total number of tokens minted in `edition` won't exceed `type(uint32).max`,
            // and `quantity` has 32 bits.
            if (numberMinted + quantity > data.maxMintablePerAccount) revert ExceedsMaxPerAccount();
        }

        data.totalMinted = _incrementTotalMinted(data.totalMinted, quantity, data.maxMintable);

        _mint(edition, mintId, quantity, affiliate);
    }

    /**
     * @inheritdoc IDutchAuctionMinter
     */
    function setDutchAuctionConfig(
        address edition,
        uint128 mintId,
        uint96 startPrice,
        uint32 decreaseInterval,
        uint96 decreaseSize,
        uint32 numDecreases
    ) public onlyEditionOwnerOrAdmin(edition) {
        _editionMintData[edition][mintId].startPrice = startPrice;
        _editionMintData[edition][mintId].decreaseInterval = decreaseInterval;
        _editionMintData[edition][mintId].decreaseSize = decreaseSize;
        _editionMintData[edition][mintId].numDecreases = numDecreases;
        emit AuctionConfigSet(edition, mintId, startPrice, decreaseInterval, decreaseSize, numDecreases);
    }

    /**
     * @inheritdoc IDutchAuctionMinter
     */
    function setMaxMintable(
        address edition,
        uint128 mintId,
        uint32 maxMintable
    ) public onlyEditionOwnerOrAdmin(edition) {
        _editionMintData[edition][mintId].maxMintable = maxMintable;
        emit MaxMintableSet(edition, mintId, maxMintable);
    }

    /**
     * @inheritdoc IDutchAuctionMinter
     */
    function setMaxMintablePerAccount(
        address edition,
        uint128 mintId,
        uint32 maxMintablePerAccount
    ) public onlyEditionOwnerOrAdmin(edition) {
        if (maxMintablePerAccount == 0) revert MaxMintablePerAccountIsZero();
        _editionMintData[edition][mintId].maxMintablePerAccount = maxMintablePerAccount;
        emit MaxMintablePerAccountSet(edition, mintId, maxMintablePerAccount);
    }

    // =============================================================
    //               PUBLIC / EXTERNAL VIEW FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc IMinterModule
     */
    function totalPrice(
        address edition,
        uint128 mintId,
        address, /* minter */
        uint32 quantity
    ) public view virtual override(BaseMinter, IMinterModule) returns (uint128) {
        unchecked {
            BaseData memory baseData = _baseData[edition][mintId];
            EditionMintData storage mintData = _editionMintData[edition][mintId];
            // solhint-disable-next-line not-rely-on-time
            uint256 currentTime = block.timestamp;

            uint256 decreases = Math.min(
                (currentTime - baseData.startTime) / mintData.decreaseInterval,
                mintData.numDecreases
            );

            // Will not overflow, as `price` is 96 bits, and `quantity` is 32 bits. 96 + 32 = 128.
            return uint128(quantity * (mintData.startPrice - decreases * mintData.decreaseSize));
        }
    }

    /**
     * @inheritdoc IDutchAuctionMinter
     */
    function mintInfo(address edition, uint128 mintId) external view returns (MintInfo memory info) {
        BaseData memory baseData = _baseData[edition][mintId];
        EditionMintData storage mintData = _editionMintData[edition][mintId];

        info.startTime = baseData.startTime;
        info.endTime = baseData.endTime;
        info.affiliateFeeBPS = baseData.affiliateFeeBPS;
        info.mintPaused = baseData.mintPaused;
        info.startPrice = mintData.startPrice;
        info.decreaseInterval = mintData.decreaseInterval;
        info.decreaseSize = mintData.decreaseSize;
        info.numDecreases = mintData.numDecreases;
        info.maxMintable = mintData.maxMintable;
        info.maxMintablePerAccount = mintData.maxMintablePerAccount;
        info.totalMinted = mintData.totalMinted;
    }

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(bytes4 interfaceId) public view override(IERC165, BaseMinter) returns (bool) {
        return BaseMinter.supportsInterface(interfaceId) || interfaceId == type(IDutchAuctionMinter).interfaceId;
    }

    /**
     * @inheritdoc IMinterModule
     */
    function moduleInterfaceId() public pure returns (bytes4) {
        return type(IDutchAuctionMinter).interfaceId;
    }
}
