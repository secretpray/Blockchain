import { Controller } from "@hotwired/stimulus"
import { BrowserProvider, formatEther } from "ethers"

// TransactionHistory controller to fetch and display recent transactions for a given wallet address
export default class extends Controller {
  static targets = ["list", "empty", "loading"]
  static values = { address: String }

  async connect() {
    await this.fetchTransactions()
  }

  async fetchTransactions() {
    try {
      if (!this.hasAddressValue || !this.addressValue) {
        console.warn("No wallet address provided")
        return
      }

      this.showLoading()

      // Try Etherscan API first (free tier, no API key needed for basic queries)
      const transactions = await this.fetchFromEtherscan()

      if (transactions && transactions.length > 0) {
        this.renderTransactions(transactions.slice(0, 10)) // Show last 10
      } else {
        this.showEmpty()
      }
    } catch (error) {
      console.error("Error fetching transactions:", error)
      // Try fallback method using provider
      await this.fetchFromProvider()
    }
  }

  async fetchFromEtherscan() {
    // Using Etherscan API without key (limited to 5 requests/sec)
    const apiUrl = `https://api.etherscan.io/api?module=account&action=txlist&address=${this.addressValue}&startblock=0&endblock=99999999&page=1&offset=10&sort=desc`

    const response = await fetch(apiUrl)
    const data = await response.json()

    if (data.status === "1" && data.result) {
      return data.result
    }

    return null
  }

  async fetchFromProvider() {
    // Fallback: get recent blocks and filter transactions
    // This is slower but doesn't require API key
    try {
      if (!window.ethereum) {
        this.showEmpty()
        return
      }

      const provider = new BrowserProvider(window.ethereum)
      const currentBlock = await provider.getBlockNumber()
      const transactions = []

      // Check last 100 blocks (roughly 20 minutes of history)
      for (let i = 0; i < 100 && transactions.length < 10; i++) {
        const block = await provider.getBlock(currentBlock - i, true)
        if (block && block.transactions) {
          for (const tx of block.transactions) {
            if (typeof tx === 'object' &&
                (tx.from?.toLowerCase() === this.addressValue.toLowerCase() ||
                 tx.to?.toLowerCase() === this.addressValue.toLowerCase())) {
              transactions.push({
                hash: tx.hash,
                from: tx.from,
                to: tx.to,
                value: tx.value?.toString() || "0",
                timeStamp: block.timestamp?.toString() || "",
                blockNumber: block.number?.toString() || ""
              })
            }
          }
        }
      }

      if (transactions.length > 0) {
        this.renderTransactions(transactions)
      } else {
        this.showEmpty()
      }
    } catch (error) {
      console.error("Error fetching from provider:", error)
      this.showEmpty()
    }
  }

  renderTransactions(transactions) {
    if (!this.hasListTarget) return

    this.hideLoading()
    this.hideEmpty()

    this.listTarget.innerHTML = transactions.map(tx => {
      const value = formatEther(tx.value || "0")
      const isReceived = tx.to?.toLowerCase() === this.addressValue.toLowerCase()
      const date = tx.timeStamp ? new Date(parseInt(tx.timeStamp) * 1000).toLocaleDateString() : "Unknown"
      const time = tx.timeStamp ? new Date(parseInt(tx.timeStamp) * 1000).toLocaleTimeString() : ""

      const txHash = tx.hash || ""
      const shortHash = txHash ? `${txHash.slice(0, 6)}...${txHash.slice(-4)}` : "Unknown"
      const otherAddress = isReceived ? tx.from : tx.to
      const shortAddress = otherAddress ? `${otherAddress.slice(0, 6)}...${otherAddress.slice(-4)}` : "Unknown"

      return `
        <div class="flex items-center justify-between p-4 border-b border-border/50 hover:bg-muted/20 transition-colors">
          <div class="flex items-center gap-3">
            <div class="w-10 h-10 rounded-full flex items-center justify-center ${isReceived ? 'bg-green-500/20' : 'bg-orange-500/20'}">
              ${isReceived ? `
                <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="text-green-500">
                  <line x1="12" y1="5" x2="12" y2="19"></line>
                  <polyline points="19 12 12 19 5 12"></polyline>
                </svg>
              ` : `
                <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="text-orange-500">
                  <line x1="12" y1="5" x2="12" y2="19"></line>
                  <polyline points="5 12 12 5 19 12"></polyline>
                </svg>
              `}
            </div>
            <div class="flex flex-col">
              <span class="text-sm font-medium">${isReceived ? 'Received' : 'Sent'}</span>
              <span class="text-xs text-muted-foreground font-mono">${shortAddress}</span>
            </div>
          </div>
          <div class="flex flex-col items-end">
            <span class="text-sm font-mono font-semibold ${isReceived ? 'text-green-500' : 'text-orange-500'}">
              ${isReceived ? '+' : '-'}${parseFloat(value).toFixed(4)} ETH
            </span>
            <div class="flex items-center gap-2 text-xs text-muted-foreground">
              <span>${date} ${time}</span>
              <a href="https://etherscan.io/tx/${txHash}" target="_blank" rel="noopener noreferrer" class="hover:text-primary">
                ${shortHash}
              </a>
            </div>
          </div>
        </div>
      `
    }).join('')
  }

  showLoading() {
    if (this.hasLoadingTarget) this.loadingTarget.classList.remove('hidden')
    if (this.hasEmptyTarget) this.emptyTarget.classList.add('hidden')
  }

  hideLoading() {
    if (this.hasLoadingTarget) this.loadingTarget.classList.add('hidden')
  }

  showEmpty() {
    this.hideLoading()
    if (this.hasEmptyTarget) this.emptyTarget.classList.remove('hidden')
  }

  hideEmpty() {
    if (this.hasEmptyTarget) this.emptyTarget.classList.add('hidden')
  }

  async refresh() {
    await this.fetchTransactions()
  }
}
