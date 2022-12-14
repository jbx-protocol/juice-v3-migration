// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import '../V1Allocator.sol';
import 'forge-std/Script.sol';


contract Deploy_V1_Allocator_On_Mainnet is Script {

    IJBDirectoryV3 jbV3Directory = IJBDirectoryV3(0x65572FB928b46f9aDB7cfe5A4c41226F636161ea);
    V1Allocator v1Allocator;

    function run() external {
      vm.startBroadcast();

      v1Allocator = new V1Allocator(jbV3Directory);
      console.log(address(v1Allocator));
    }
}

contract Deploy_V1_Allocator_On_Goerli is Script {

    IJBDirectoryV3 jbV3Directory = IJBDirectoryV3(0x8E05bcD2812E1449f0EC3aE24E2C395F533d9A99);
    V1Allocator v1Allocator;

    function run() external {
      vm.startBroadcast();

      v1Allocator = new V1Allocator(jbV3Directory);
      console.log(address(v1Allocator));
    }
}