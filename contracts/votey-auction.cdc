// VoteyAuction.cdc
//
// The VoteyAuction contract is an experimental implementation of an NFT Auction on Flow.
//
// This contract allows users to put their NFTs up for sale. Other users
// can purchase these NFTs with fungible tokens.
//
import FungibleToken from 0xee82856bf20e2aa6
import NonFungibleToken from 0xe03daebed8ca0615

// Contract Deployment:
// Acct 1 - 0x01cf0e2f2f715450 - demo-token.cdc
// Acct 2 - 0x179b6b1cb6755e31 - rocks.cdc
// Acct 3 - 0xf3fcd2c1a78f5eee - votey-auction.cdc
// Acct 4 - 0xe03daebed8ca0615 - onflow/NonFungibleToken.cdc
//

pub contract VoteyAuction {

    // Events
    pub event NewAuctionCollectionCreated(minimumBidIncrement: UFix64, auctionLengthInBlocks: UInt64)
    pub event TokenAddedToAuctionQueue(tokenID: UInt64, startPrice: UFix64)
    pub event TokenStartPriceUpdated(tokenID: UInt64, newPrice: UFix64)

    pub resource interface AuctionPublic {
        pub fun getAuctionQueuePrices(): {UInt64: UFix64}
    }

    pub resource AuctionCollection: AuctionPublic {

        // Auction Items
        pub var auctionQueue: @{UInt64: NonFungibleToken.NFT}
        pub var currentAuctionItem: @[NonFungibleToken.NFT]

        // Current Price
        pub var currentAuctionPrice: UFix64

        // Auction Queue Meta Data
        pub var auctionQueuePrices: {UInt64: UFix64}
        pub var auctionQueueVotes: {UInt64: UInt64}

        // Auction Settings
        pub let minimumBidIncrement: UFix64
        pub let auctionLengthInBlocks: UInt64
        pub var auctionStartBlock: UInt64

        // Vaults
        pub let ownerVault: &AnyResource{FungibleToken.Receiver}
        pub let bidVault: @FungibleToken.Vault


        init(
            minimumBidIncrement: UFix64,
            auctionLengthInBlocks: UInt64,
            ownerVault: &AnyResource{FungibleToken.Receiver},
            ownerNFTCollection: &AnyResource{NonFungibleToken.CollectionPublic},
            bidVault: @FungibleToken.Vault
        ) {
            self.auctionQueue <- {}
            self.currentAuctionItem <- []
            self.currentAuctionPrice = UFix64(0)
            self.auctionQueuePrices = {}
            self.auctionQueueVotes = {}
            self.minimumBidIncrement = minimumBidIncrement
            self.auctionLengthInBlocks = auctionLengthInBlocks
            self.auctionStartBlock = UInt64(0)
            self.ownerVault = ownerVault
            self.bidVault <- bidVault
        }

        // addTokenToAuctionQueue adds a token to the auction queue, sets the start price
        // and sets the vote count to 0
        pub fun addTokenToAuctionQueue(token: @NonFungibleToken.NFT, startPrice: UFix64) {
            // store the token ID
            let tokenID = token.id

            // update the auction queue prices dictionary
            self.changeStartPrice(tokenID: tokenID, newPrice: startPrice)

            // set the initial vote count to 0
            self.auctionQueueVotes[tokenID] = UInt64(0)

            // add the token to the auction queue
            let oldToken <- self.auctionQueue[tokenID] <- token
            destroy oldToken


            emit TokenAddedToAuctionQueue(tokenID: tokenID, startPrice: startPrice)
        }

        // changeStartPrice updates the start price value for an NFT in the auction queue
        pub fun changeStartPrice(tokenID: UInt64, newPrice: UFix64) {
            self.auctionQueuePrices[tokenID] = newPrice

            emit TokenStartPriceUpdated(tokenID: tokenID, newPrice: newPrice)
        }

        // getAuctionQueuePrices 
        pub fun getAuctionQueuePrices(): {UInt64: UFix64} {
            return self.auctionQueuePrices
        }

        // startAuction removes the token with the highest ID number from the
        // auction queue and puts it up for auction
        pub fun startAuction() {
            self.updateCurrentAuctionItem()
        }

        // updateCurrentAuctionItem adds the next token from the auction queue
        // to the currentAuctionItem array
        pub fun updateCurrentAuctionItem() {
            pre {
                self.currentAuctionItem.length == 0:
                "can not have more than one active auction item"
            }
            // get the next token ID
            var tokenID = self.getNextTokenID()
            // update the auction start price
            self.currentAuctionPrice = self.auctionQueuePrices[tokenID]??
                panic("no token in the auction queue")
            // remove the next token from the auction queue
            let token <- self.getTokenFromAuctionQueue(tokenID: tokenID)
            // append the token to the currentAuctionItem array
            self.currentAuctionItem.append(<-token)
        }

        // getNextTokenID returns the token ID with the highest vote count, if any.
        // Otherwise it returns the tokenID with the highest ID number
        pub fun getNextTokenID(): UInt64 {
            var tokenID = self.getHighestVoteCountID()

            if tokenID == nil {
                tokenID = self.getHighestTokenID()
            }

            return tokenID!
        }

        // getHighestVoteCountID returns the id for the token with the
        // highest vote count, or nil if all votes equal zero
        pub fun getHighestVoteCountID(): UInt64? {
            pre {
                self.auctionQueue.keys.length > 0:
                    "there are no tokens in the auction queue"
            }

            var tokenID: UInt64? = nil
            var highestCount: UInt64 = 0
            var counter: UInt64 = 0

            // while there are still tokens to loop through...
            while counter < UInt64(self.auctionQueueVotes.keys.length) {
                // ... if the vote count is higher than the current highest count...
                if self.auctionQueueVotes[counter]! > highestCount {
                    // ... update the current highest count for the next iteration
                    highestCount = self.auctionQueueVotes[self.auctionQueueVotes.keys[counter]]
                        ?? panic("auction queue is out of sync")
                    // ... set the token ID to the token with the highest count
                    tokenID = self.auctionQueueVotes.keys[counter]
                }
            }

            // return the token ID with the most votes (or nil)
            return tokenID
        }

        // getHighestTokenID returns the highest token ID in the auction queue
        pub fun getHighestTokenID(): UInt64 {
            pre {
                self.auctionQueue.keys.length > 0:
                    "there are no tokens in the auction queue"
            }

            // set the initial tokenID to zero (no token ids will be lower than this)
            var tokenID: UInt64 = 0

            // for each token ID in the auction queue...
            for id in self.auctionQueue.keys {
                // ...if the token ID is greater than the
                // ID we currently have stored
                if id > tokenID {
                    //...update tokenID to the higher ID
                    tokenID = id
                }
            }
            
            return tokenID
        }

        // getTokenFromAuctionQueue removes the token from the auction queue
        // and returns it to the caller
        pub fun getTokenFromAuctionQueue(tokenID: UInt64): @NonFungibleToken.NFT {
            pre {
                self.auctionQueue.keys.length > 0:
                    "there are no tokens in the auction queue"
            }

            // remove vote and prices data
            self.auctionQueuePrices[tokenID] = nil
            self.auctionQueueVotes[tokenID] = nil

            // withdraw token and return it to the caller
            let nextToken <- self.auctionQueue.remove(key: tokenID)!
            return <- nextToken
        }

        destroy() {
            destroy self.auctionQueue
            destroy self.currentAuctionItem
            destroy self.bidVault
        }
    }

    // createAuctionCollection returns a new AuctionCollection resource to the caller
    pub fun createAuctionCollection(
        minimumBidIncrement: UFix64,
        auctionLengthInBlocks: UInt64,
        ownerVault: &AnyResource{FungibleToken.Receiver},
        ownerNFTCollection: &AnyResource{NonFungibleToken.CollectionPublic},
        bidVault: @FungibleToken.Vault
    ): @AuctionCollection {

        let auctionCollection <- create AuctionCollection(
            minimumBidIncrement: minimumBidIncrement,
            auctionLengthInBlocks: auctionLengthInBlocks,
            ownerVault: ownerVault,
            ownerNFTCollection: ownerNFTCollection,
            bidVault: <-bidVault
        )

        emit NewAuctionCollectionCreated(minimumBidIncrement: minimumBidIncrement, auctionLengthInBlocks: auctionLengthInBlocks)

        return <- auctionCollection
    }

    init() {
        log("Auction contract deployed")
    }
    
}
 