import { Controller } from "@hotwired/stimulus"
import { BrowserProvider, formatEther } from "ethers"

// WalletBalance controller to fetch and display the ETH balance of a given wallet address
export default class extends Controller {
  static targets = ["balance", "usdValue", "status"]
  static values = { address: String }

  async connect() {
    await this.fetchBalance()
  }

  async fetchBalance() {
    try {
      if (!this.hasAddressValue || !this.addressValue) {
        console.warn("No wallet address provided")
        return
      }

      // Try to get balance from Web3 provider (MetaMask)
      if (window.ethereum) {
        await this.fetchBalanceFromProvider()
      } else {
        // Fallback to public RPC if no MetaMask
        await this.fetchBalanceFromPublicRPC()
      }

      // Fetch ETH price in USD
      await this.fetchEthPrice()
    } catch (error) {
      console.error("Error fetching balance:", error)
      this.updateStatus("Failed to fetch balance")
    }
  }

  async fetchBalanceFromProvider() {
    const provider = new BrowserProvider(window.ethereum)
    const balance = await provider.getBalance(this.addressValue)
    const ethBalance = formatEther(balance)

    this.updateBalance(ethBalance)
  }

  async fetchBalanceFromPublicRPC() {
    // Using Cloudflare's public Ethereum gateway
    // You can replace this with Infura/Alchemy if you have API keys
    const response = await fetch("https://cloudflare-eth.com", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        jsonrpc: "2.0",
        method: "eth_getBalance",
        params: [this.addressValue, "latest"],
        id: 1
      })
    })

    const data = await response.json()
    if (data.result) {
      // Convert hex balance to ETH
      const balanceWei = BigInt(data.result)
      const ethBalance = formatEther(balanceWei)
      this.updateBalance(ethBalance)
    }
  }

  async fetchEthPrice() {
    try {
      // Using CoinGecko free API
      const response = await fetch(
        "https://api.coingecko.com/api/v3/simple/price?ids=ethereum&vs_currencies=usd"
      )
      const data = await response.json()
      const ethPrice = data?.ethereum?.usd

      if (ethPrice && this.hasBalanceTarget) {
        const ethBalance = parseFloat(this.balanceTarget.textContent)
        const usdValue = (ethBalance * ethPrice).toFixed(2)
        this.updateUsdValue(usdValue)
      }
    } catch (error) {
      console.warn("Could not fetch ETH price:", error)
    }
  }

  updateBalance(ethBalance) {
    if (this.hasBalanceTarget) {
      // Format to 4 decimal places
      const formatted = parseFloat(ethBalance).toFixed(4)
      this.balanceTarget.textContent = formatted
    }
  }

  updateUsdValue(usdValue) {
    if (this.hasUsdValueTarget) {
      this.usdValueTarget.textContent = `≈ $${usdValue} USD`
    }
  }

  updateStatus(message) {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = message
    }
  }

  async refresh() {
    this.updateStatus("Refreshing...")
    await this.fetchBalance()
    this.updateStatus("")
  }
}
