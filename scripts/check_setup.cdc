// This script checks that the accounts are set up correctly for the marketplace tutorial.
//
// Account 0x01: DemoToken Vault Balance = 100, NFT.id[1 - 10]
// Account 0x02: DemoToken Vault Balance = 200, No NFTs
// Account 0x03: DemoToken Vault Balance = 200, No NFTs
// Account 0x04: DemoToken Vault Balance = 200, No NFTs

import FungibleToken from 0xee82856bf20e2aa6
import NonFungibleToken from 0xe03daebed8ca0615
import DemoToken from 0x01cf0e2f2f715450
import Rocks from 0x179b6b1cb6755e31

// Contract Deployment:
// Acct 1 - 0x01cf0e2f2f715450 - demo-token.cdc
// Acct 2 - 0x179b6b1cb6755e31 - rocks.cdc
// Acct 3 - 0xf3fcd2c1a78f5eee - marketplace.cdc
// Acct 4 - 0xe03daebed8ca0615 - onflow/NonFungibleToken.cdc

pub fun main() {
    // get the accounts' public address objects
    let account1 = getAccount(0x01cf0e2f2f715450)
    let account2 = getAccount(0x179b6b1cb6755e31)
    let account3 = getAccount(0xf3fcd2c1a78f5eee)
    let account4 = getAccount(0xe03daebed8ca0615)

    // get the reference to the account's receivers
    // by getting their public capability
    // and borrowing a reference from the capability
    let account1ReceiverRef = account1.getCapability(/public/DemoTokenBalance)!
                                      .borrow<&DemoToken.Vault{FungibleToken.Balance}>()
                                      ?? panic("could not borrow the vault balance reference for account 1")
    
    let account2ReceiverRef = account2.getCapability(/public/DemoTokenBalance)!
                                      .borrow<&DemoToken.Vault{FungibleToken.Balance}>()
                                      ?? panic("could not borrow the vault balance reference for account 2")

    let account3ReceiverRef = account3.getCapability(/public/DemoTokenBalance)!
                                      .borrow<&DemoToken.Vault{FungibleToken.Balance}>()
                                      ?? panic("could not borrow the vault balance reference for account 3")

    let account4ReceiverRef = account4.getCapability(/public/DemoTokenBalance)!
                                      .borrow<&DemoToken.Vault{FungibleToken.Balance}>()
                                      ?? panic("could not borrow the vault balance reference for account 4")
    
    // log the Vault balance of both accounts
    // and ensure they are the correct numbers
    // Account 1 should have 100
    // Account 2 should have 200
    // Account 3 should have 200
    // Account 4 should have 200

    log("Account 1 DemoToken Balance:")
    log(account1ReceiverRef.balance)
    
    log("Account 2 DemoToken Balance:")
    log(account2ReceiverRef.balance)

    log("Account 3 DemoToken Balance:")
    log(account2ReceiverRef.balance)

    log("Account 4 DemoToken Balance:")
    log(account2ReceiverRef.balance)


    // verify that the balances are correct
    if account1ReceiverRef.balance != UFix64(100) || account2ReceiverRef.balance != UFix64(200) || account3ReceiverRef.balance != UFix64(200) || account4ReceiverRef.balance != UFix64(200) {
        panic("Account balances are incorrect!")
    }

    // find the public receiver capability for their Collections
    let account1NFTCapability = account1.getCapability(/public/RockCollection)!
    let account2NFTCapability = account2.getCapability(/public/RockCollection)!
    let account3NFTCapability = account3.getCapability(/public/RockCollection)!
    let account4NFTCapability = account4.getCapability(/public/RockCollection)!

    // borrow references from the capabilities
    let account1NFTRef = account1NFTCapability.borrow<&{Rocks.PublicCollectionMethods}>()
                        ?? panic("unable to borrow a reference to NFT collection for Account 1")
    let account2NFTRef = account2NFTCapability.borrow<&{Rocks.PublicCollectionMethods}>()
                        ?? panic("unable to borrow a reference to NFT collection for Account 2")
    let account3NFTRef = account3NFTCapability.borrow<&{Rocks.PublicCollectionMethods}>()
                        ?? panic("unable to borrow a reference to NFT collection for Account 3")
    let account4NFTRef = account4NFTCapability.borrow<&{Rocks.PublicCollectionMethods}>()
                        ?? panic("unable to borrow a reference to NFT collection for Account 4")

    // print both collections as arrays of ids
    log("Account 1 NFT IDs")
    log(account1NFTRef.getIDs())
    
    log("Account 2 NFT IDs")
    log(account2NFTRef.getIDs())
    
    log("Account 3 NFT IDs")
    log(account3NFTRef.getIDs())
    
    log("Account 4 NFT IDs")
    log(account4NFTRef.getIDs())

    // verify that the collections are correct
    if account1NFTRef.getIDs().length == 0 || account2NFTRef.getIDs().length != 0 || account3NFTRef.getIDs().length != 0 || account4NFTRef.getIDs().length != 0 {
        panic("Wrong NFT Collections!")
    }
}
 