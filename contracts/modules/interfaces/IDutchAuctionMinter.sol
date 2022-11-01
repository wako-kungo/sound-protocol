// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { IMinterModule } from "@core/interfaces/IMinterModule.sol";

/**
 * @dev Data unique to a Dutch Auction mint.
 */
struct EditionMintData {
    // The startPrice of the auction, in ETH.
    uint96 startPrice;
    // The time interval of price decreases, in seconds.
    uint32 decreaseInterval;
    // The amount to decrease per interval, in ETH.
    uint96 decreaseSize;
    // The number of price decreases that should happen.
    uint32 numDecreases;
    // The maximum number of tokens that can can be minted for this sale.
    uint32 maxMintable;
    // The maximum number of tokens that a wallet can mint.
    uint32 maxMintablePerAccount;
    // The total number of tokens minted so far for this sale.
    uint32 totalMinted;
}

/**
 * @dev All the information about a edition max mint (combines EditionMintData with BaseData).
 */
struct MintInfo {
    uint32 startTime;
    uint32 endTime;
    uint16 affiliateFeeBPS;
    bool mintPaused;
    uint96 startPrice;
    uint32 decreaseInterval;
    uint96 decreaseSize;
    uint32 numDecreases;
    uint32 maxMintable;
    uint32 maxMintablePerAccount;
    uint32 totalMinted;
}

/**
 * @title IDutchAuctionMinter
 * @dev Interface for the `DutchAuctionMinter` module.
 * @author Wako Kungo
 */
interface IDutchAuctionMinter is IMinterModule {
    // =============================================================
    //                            EVENTS
    // =============================================================

    /**
     * @dev Emitted when a Dutch Auction is created.
     * @param edition               Address of the song edition contract we are minting for.
     * @param mintId                The mint ID.
     * @param startPrice            Start sale price in ETH for minting a single token in `edition`.  
     * @param startTime             Start timestamp of sale (in seconds since unix epoch).
     * @param decreaseInterval      The time interval of price decreases, in seconds.
     * @param decreaseSize          The amount in ETH to decrease per interval.
     * @param numDecreases          The number of price decreases that should happen.
     * @param endTime               End timestamp of sale (in seconds since unix epoch).
     * @param affiliateFeeBPS       The affiliate fee in basis points.
     * @param maxMintable           The maximum number of tokens that can be minted.
     * @param maxMintablePerAccount The maximum number of tokens that can be minted per account.
     */
    event DutchAuctionMintCreated(
        address indexed edition,
        uint128 indexed mintId,
        uint96 startPrice,
        uint32 startTime,
        uint32 decreaseInterval,
        uint96 decreaseSize,
        uint32 numDecreases,
        uint32 endTime,
        uint16 affiliateFeeBPS,
        uint32 maxMintable,
        uint32 maxMintablePerAccount
    );

    /**
     * @dev Emitted when the `price` is changed for (`edition`, `mintId`).
     * @param edition          Address of the song edition contract we are minting for.
     * @param mintId           The mint ID.
     * @param startPrice       Sale price in ETH for minting a single token in `edition`.
     * @param decreaseInterval The time interval of price decreases, in seconds.
     * @param decreaseSize     The amount in ETH to decrease per interval.
     * @param numDecreases     The number of price decreases that should happen.
     */
    event AuctionConfigSet(
        address indexed edition, 
        uint128 indexed mintId, 
        uint96 startPrice, 
        uint32 decreaseInterval,
        uint96 decreaseSize,
        uint32 numDecreases
    );

    /**
     * @dev Emitted when the `maxMintable` is changed for (`edition`, `mintId`).
     * @param edition     Address of the song edition contract we are minting for.
     * @param mintId      The mint ID.
     * @param maxMintable The maximum number of tokens that can be minted on this schedule.
     */
    event MaxMintableSet(address indexed edition, uint128 indexed mintId, uint32 maxMintable);

    /**
     * @dev Emitted when the `maxMintablePerAccount` is changed for (`edition`, `mintId`).
     * @param edition               Address of the song edition contract we are minting for.
     * @param mintId                The mint ID.
     * @param maxMintablePerAccount The maximum number of tokens that can be minted per account.
     */
    event MaxMintablePerAccountSet(address indexed edition, uint128 indexed mintId, uint32 maxMintablePerAccount);

    // =============================================================
    //                            ERRORS
    // =============================================================

    /**
     * @dev The number of tokens minted has exceeded the number allowed for each account.
     */
    error ExceedsMaxPerAccount();

    /**
     * @dev The max mintable per account cannot be zero.
     */
    error MaxMintablePerAccountIsZero();

    // =============================================================
    //               PUBLIC / EXTERNAL WRITE FUNCTIONS
    // =============================================================

    /*
     * @dev Initializes a range mint instance
     * @param edition               Address of the song edition contract we are minting for.
     * @param startPrice            Start sale price in ETH for minting a single token in `edition`.  
     * @param startTime             Start timestamp of sale (in seconds since unix epoch).
     * @param decreaseInterval      The time interval of price decreases, in seconds.
     * @param decreaseSize          The amount in ETH to decrease per interval.
     * @param numDecreases          The number of price decreases that should happen.
     * @param endTime               End timestamp of sale (in seconds since unix epoch).
     * @param affiliateFeeBPS       The affiliate fee in basis points.
     * @param maxMintableLower      The lower limit of the maximum number of tokens that can be minted.
     * @param maxMintableUpper      The upper limit of the maximum number of tokens that can be minted.
     * @param maxMintablePerAccount The maximum number of tokens that can be minted by an account.
     * @return mintId The ID for the new mint instance.
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
    ) external returns (uint128 mintId);

    /*
     * @dev Mints tokens for a given edition.
     * @param edition   Address of the song edition contract we are minting for.
     * @param mintId    The mint ID.
     * @param quantity  Token quantity to mint in song `edition`.
     * @param affiliate The affiliate address.
     */
    function mint(
        address edition,
        uint128 mintId,
        uint32 quantity,
        address affiliate
    ) external payable;

    /*
     * @dev Sets the `maxMintablePerAccount` for (`edition`, `mintId`).
     * @param edition               Address of the song edition contract we are minting for.
     * @param mintId                The mint ID.
     * @param startPrice            Start sale price in ETH for minting a single token in `edition`.
     * @param decreaseInterval      The time interval of price decreases, in seconds.
     * @param decreaseSize          The amount in ETH to decrease per interval.
     * @param numDecreases          The number of price decreases that should happen.
     */
    function setDutchAuctionConfig(
        address edition,
        uint128 mintId,
        uint96 startPrice,
        uint32 decreaseInterval,
        uint96 decreaseSize,
        uint32 numDecreases
    ) external;

    /*
     * @dev Sets the `maxMintable` for (`edition`, `mintId`).
     * @param edition     Address of the song edition contract we are minting for.
     * @param mintId      The mint ID.
     * @param maxMintable The maximum number of tokens that can be minted on this schedule.
     */
    function setMaxMintable(
        address edition,
        uint128 mintId,
        uint32 maxMintable
    ) external;

    /*
     * @dev Sets the `maxMintablePerAccount` for (`edition`, `mintId`).
     * @param edition               Address of the song edition contract we are minting for.
     * @param mintId                The mint ID.
     * @param maxMintablePerAccount The maximum number of tokens that can be minted by an account.
     */
    function setMaxMintablePerAccount(
        address edition,
        uint128 mintId,
        uint32 maxMintablePerAccount
    ) external;

    // =============================================================
    //               PUBLIC / EXTERNAL VIEW FUNCTIONS
    // =============================================================

    /**
     * @dev Returns {IEditionMaxMinter.MintInfo} instance containing the full minter parameter set.
     * @param edition The edition to get the mint instance for.
     * @param mintId  The ID of the mint instance.
     * @return mintInfo Information about this mint.
     */
    function mintInfo(address edition, uint128 mintId) external view returns (MintInfo memory);
}
