# @title Serenus Coin Oracle contract
# @notice Gets a mid-price from the Uniswap ETH/Dai pool on-chain
# @notice Source code found at https://github.com/serenuscoin
# @notice Use at your own risk
# @dev Compiled with Vyper 0.1.0b5

# 0xDDaa82Cd9168C522De750Ef3b305A18C20085a87

# @dev Reads balances from the mainnet MakerDAO Dai contract
contract Dai:
    def balanceOf(_address: address) -> uint256(wei): constant

daiContract: Dai                       # Dai ERC20 address
owner: public(address)                 # Owner
uniswap_ethdai_pool: public(address)   # Uniswap's ETH/Dai pool

# @notice Sets up addresses for the Dai ERC20 and the Uniswap pool for ETH/Dai
@public
def __init__():
    self.owner = msg.sender
    self.uniswap_ethdai_pool = 0x09cabEC1eAd1c0Ba254B09efb3EE13841712bE14
    self.daiContract = 0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359

@public
def liquidate():
    assert msg.sender == self.owner
    selfdestruct(self.owner)
    
@public
def setUniswapETHDAIPool(_address: address):
    assert msg.sender == self.owner
    self.uniswap_ethdai_pool = _address

@public
def setDaiContract(_address: address):
    assert msg.sender == self.owner
    self.daiContract = _address

# @notice Reads instantaneous midprice for ETH/Dai exchanges
# @return A price as an integer to the nearest cent
@public
def read() -> uint256:
    _eth_balance: uint256(wei) = self.uniswap_ethdai_pool.balance
    _dai_balance: uint256(wei) = self.daiContract.balanceOf(self.uniswap_ethdai_pool)
    return (_dai_balance * 100) / _eth_balance

