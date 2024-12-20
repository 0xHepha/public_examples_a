// @0xe46a3c36283330c97668b5d4693766b8626420a5701c18eb64026075c3ec8a0a
// @0xfab16b00983f01e5c2b7682472a4f4c3e5929fbba987958570b6290c02817df2
// @0x9281d2b12c08c1292eb547d9a896c24b15cc855e2936c63eb1012a76ef985820


module creator::ark {
    use std::signer;
    use std::vector;
    use std::string::{Self, String};
    use std::string_utils;

    use aptos_framework::account;
    use aptos_framework::coin;
    use aptos_framework::object::{Self};
    use aptos_framework::aptos_coin::{AptosCoin};


    use aptos_token_objects::collection::{Collection};
    use aptos_token_objects::token;

    use aptos_token_objects::aptos_token::{Self,AptosToken};

    // CONSTANTS
    const ARK_ADDRESS: address = @creator;
    const PRICE: u64 = 13000000; // 0.13 * 10**8
    const SNEAK_PRICE: u64 = 100000000;

    const SEED: vector<u8> = b"33";

    // ERRORS
    // Caller not judge
    const ENOT_JUDGE: u64 = 1;

    // The caller isn't the owner of the token at specified address
    const ENOT_TOKEN_OWNER : u64 = 2;

    // THe token of the specified address isn't from the collection
    const ENOT_TOKEN_FROM_COLLECTION : u64 = 3;

    // The ark didn't land yet, if you exit you drown
    const EARK_STILL_TRAVELLING: u64 = 4;

    // The caller didn't submit this token
    const ETHIEF: u64 = 5;

    // This token it isn't purified yet
    const ENOT_PURIFIED: u64 = 6;

    // The ark is closed already
    const EARK_CLOSED: u64 = 7;


    struct ArkData has key{
      collection_address: address,
      tokens_amount: u64,
      judge: address,
      open: bool
    }
  
    /// A struct used in an object to hold the information about the Resource Account
    struct ResourceInfo has key {
        /// Signer capability for the resource account
        resource_cap: account::SignerCapability
    }

  /// Initializes a candy machine minter for a collection
    fun init_module(creator: &signer) {

      move_to(creator, ArkData{
        collection_address: ARK_ADDRESS,
        tokens_amount: 0,
        judge: @creator,
        open: true
      });

      createCollection_internal(creator);
    }

 
    fun createCollection_internal(creator: &signer){
      let collection_name = string::utf8(b"Salvation Pass");
      let collection_description = string::utf8(b"Judgement day has come, only the chosen ones will survive");
      let collection_uri = string::utf8(b"https://arweave.net/oma6stQEXm4XUm8r2P6AdSisG-xrI7dK1dOdDIFOTIw/0.json");
      let supply = 10000;
      let royalty_numerator = 1000;
      let royalty_denominator = 1000;

      // Create the resource account which will hold the collection
      let (_resource, resource_cap) = account::create_resource_account(creator, SEED);
      let resource_signer_from_cap = account::create_signer_with_capability(&resource_cap);
      
      // Store the resource cap in the object
      move_to<ResourceInfo>(
        creator,
        ResourceInfo { resource_cap }
      );

      // Create the collection to be minted
      aptos_token::create_collection_object(
          &resource_signer_from_cap,
          collection_description,
          supply,
          collection_name,
          collection_uri,
          true,
          true,
          true,
          true,
          true,
          true,
          true,
          true,
          true,
          royalty_numerator,
          royalty_denominator
      );

    }

    fun mint_internal(to_address: address) acquires ResourceInfo, ArkData{     
      let collection_name = string::utf8(b"Salvation Pass");
      let collection_description = string::utf8(b"Judgement day has come, only the chosen ones will survive");
      let token_uri = string::utf8(b"https://arweave.net/oma6stQEXm4XUm8r2P6AdSisG-xrI7dK1dOdDIFOTIw/0.json");

      let data = borrow_global_mut<ArkData>(ARK_ADDRESS);

      // Get the collection creator
      let creator = getCreatorStore();

      // Prepare the token name by adding the id to the collection name
      let token_name = collection_name;
      string::append(&mut token_name, string::utf8(b" #"));
      string::append(&mut token_name, string_utils::to_string<u64>(&data.tokens_amount));

      // Min the token
      aptos_token::mint_soul_bound_token_object(
          &creator,
          collection_name,
          collection_description,
          token_name,
          token_uri,
          vector::empty<String>(),
          vector::empty<String>(),
          vector::empty<vector<u8>>(),
          to_address
      );

      data.tokens_amount = data.tokens_amount + 1;


    }

    // Function that allows a user who doesn't have a gecko to join
    public entry fun sneak(user: &signer, amount: u64) acquires ArkData, ResourceInfo{
      // get the address of the caller
      let user_address = signer::address_of(user);

      // Check to see if the ark is open
      let arkData = borrow_global<ArkData>(ARK_ADDRESS);
      assert!(arkData.open, EARK_CLOSED);


      // Get the collection creator
      let creator_store = getCreatorStore();
      let creator_store_address = signer::address_of(&creator_store);

      // Get the total amount of coins that it should pay
      let total_price = SNEAK_PRICE * amount;
      let coins = coin::withdraw<AptosCoin>(user, total_price);
      coin::deposit(creator_store_address, coins);

      // mint the tokens in a loop
      let i = 0;
      while(i < amount){
        mint_internal(user_address);

        i = i + 1;
      }


    }


    // Function to join the ark by submiting a gecko and a fee
    public entry fun join(user: &signer, tokens_address: vector<address>) acquires ArkData, ResourceInfo{
      // get the address of the caller
      let user_address = signer::address_of(user);

      // Get the collection object 
      let arkData = borrow_global<ArkData>(ARK_ADDRESS);
      let collection_object = object::address_to_object<Collection>(arkData.collection_address);

      // Check to see if the ark is open
      assert!(arkData.open, EARK_CLOSED);

      // Get the data for the object(creator) where the tokens will be stored
      let creator_store = getCreatorStore();
      let creator_store_address = signer::address_of(&creator_store);

      // Prepare the var for the loop
      let tokens_amount = vector::length(&tokens_address);
      let i = 0 ;
      while(i < tokens_amount){
        // Get each address from the list
        let token_address = vector::borrow(&tokens_address, i);
      
        // Get the token object
        let token_object = object::address_to_object<AptosToken>(*token_address);
      
        // Get the collection that the submited token is part of
        let collection_object_from_token = token::collection_object<AptosToken>(token_object);

        // Check that is the needed collection
        assert!(collection_object_from_token == collection_object, ENOT_TOKEN_FROM_COLLECTION);

        // Transfer the token to store object 
        object::transfer(user, token_object, creator_store_address);

        // Mint a soulbound token to the user
        mint_internal(user_address);

        // Keep the loop going
        i = i + 1;
      };

      // Get the total amount of coins
      let total_price = PRICE * tokens_amount;
      let coins = coin::withdraw<AptosCoin>(user, total_price);
      coin::deposit(creator_store_address, coins);

    }

    // Prepare a mergency landing function just in case
    public entry fun land(caller: &signer, tokens_address: vector<address>, to: address) acquires ResourceInfo,ArkData{
      onlyJudge(caller);

      let creator_store = getCreatorStore();

      let land_amount = vector::length(&tokens_address);
      let i = 0;
      while(i < land_amount){
        // Get each address from the list
        let token_address = vector::borrow(&tokens_address, i);
      
        // Get the token object
        let token_object = object::address_to_object<AptosToken>(*token_address);

        // Land
        object::transfer(&creator_store, token_object, to);

        i = i + 1;
        
      }

    }

    // Emergency landing just in case
    public entry fun priced_land(caller: &signer, to: address, amount: u64) acquires ResourceInfo, ArkData{
      onlyJudge(caller);
      let creator_store = getCreatorStore();

      let coins = coin::withdraw<AptosCoin>(&creator_store, amount);
      coin::deposit(to, coins);
    }


    // Backward compatibility to be able to remove tickets with next module in case a users asks for it
    public entry fun obliterate(caller: &signer, tokens_address: vector<address>)acquires ResourceInfo, ArkData{
      onlyJudge(caller);

      let creator_store = getCreatorStore();

      let tokens_amount = vector::length(&tokens_address);
      let i = 0;
      while(i < tokens_amount){
        // Get each address from the list
        let token_address = vector::borrow(&tokens_address, i);

        // Get the token object
        let token_object = object::address_to_object<AptosToken>(*token_address);

        aptos_token::burn<AptosToken>(&creator_store, token_object);

        i = i + 1;
      }

    }

    public entry fun updateCollectionAddress(caller: &signer, new_address: address) acquires ArkData{
      let data = borrow_global_mut<ArkData>(ARK_ADDRESS);    
      assert!(data.judge == signer::address_of(caller), ENOT_JUDGE);
      
      data.collection_address = new_address;
    }

    public entry fun changeJudge(caller: &signer, new_judge: address) acquires ArkData{
      let data = borrow_global_mut<ArkData>(ARK_ADDRESS);    
      assert!(data.judge == signer::address_of(caller), ENOT_JUDGE);
      
      data.judge = new_judge;
    }

    public entry fun changeArkStatus(caller: &signer, new_status: bool) acquires ArkData{
      let data = borrow_global_mut<ArkData>(ARK_ADDRESS);    
      assert!(data.judge == signer::address_of(caller), ENOT_JUDGE);

      data.open = new_status;
    }

    //Updates the uri for a token
    public entry fun changeUri(caller: &signer, object_address: address, new_uri: String) acquires ResourceInfo,ArkData{
      onlyJudge(caller);

      let token_object = object::address_to_object<AptosToken>(object_address);
      let creator = getCreatorStore();

      aptos_token::set_uri(&creator, token_object,new_uri);
      
    }

    public entry fun changeSalvationUri(caller: &signer,token_address: address, new_uri:String) acquires ResourceInfo,ArkData{
      onlyJudge(caller);

      let token_object = object::address_to_object<AptosToken>(token_address);
      let collection_object_from_token = token::collection_object<AptosToken>(token_object);
      let creator = getCreatorStore();

      aptos_token::set_collection_uri<Collection>(&creator,collection_object_from_token, new_uri);

    }

    fun getCreatorStore(): signer acquires ResourceInfo{
      let resource_data = borrow_global<ResourceInfo>(ARK_ADDRESS);
      account::create_signer_with_capability(&resource_data.resource_cap)
    }

    fun onlyJudge(caller: &signer) acquires ArkData{
      let data = borrow_global_mut<ArkData>(ARK_ADDRESS);    
      assert!(data.judge == signer::address_of(caller), ENOT_JUDGE);
    }

    public entry fun registerCreator() acquires ResourceInfo{
      let creator = getCreatorStore();
      coin::register<AptosCoin>(&creator);
      
    }

}