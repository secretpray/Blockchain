import { Controller } from "@hotwired/stimulus"
import { BrowserProvider, formatEther } from "ethers"

// TransactionHistory controller to fetch and display recent transactions for a given wallet address
export default class extends Controller {
  static targets = ["list", "empty", "loading", "transactionTemplate", "receivedIcon", "sentIcon"]
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
    if (!this.hasListTarget || !this.hasTransactionTemplateTarget) return

    this.hideLoading()
    this.hideEmpty()

    // Clear previous transactions
    this.listTarget.innerHTML = ''

    // Render each transaction using template
    transactions.forEach(tx => {
      const element = this.createTransactionElement(tx)
      this.listTarget.appendChild(element)
    })
  }

  createTransactionElement(tx) {
    // Clone the template
    const template = this.transactionTemplateTarget.content.cloneNode(true)
    const container = template.querySelector('div')

    // Calculate transaction data
    const value = formatEther(tx.value || "0")
    const isReceived = tx.to?.toLowerCase() === this.addressValue.toLowerCase()
    const date = tx.timeStamp ? new Date(parseInt(tx.timeStamp) * 1000).toLocaleDateString() : "Unknown"
    const time = tx.timeStamp ? new Date(parseInt(tx.timeStamp) * 1000).toLocaleTimeString() : ""

    const txHash = tx.hash || ""
    const shortHash = txHash ? `${txHash.slice(0, 6)}...${txHash.slice(-4)}` : "Unknown"
    const otherAddress = isReceived ? tx.from : tx.to
    const shortAddress = otherAddress ? `${otherAddress.slice(0, 6)}...${otherAddress.slice(-4)}` : "Unknown"

    // Populate the template
    const iconContainer = container.querySelector('[data-transaction-icon]')
    const icon = isReceived ? this.receivedIconTarget : this.sentIconTarget
    iconContainer.appendChild(icon.content.cloneNode(true))
    iconContainer.className = `w-10 h-10 rounded-full flex items-center justify-center ${isReceived ? 'bg-green-500/20' : 'bg-orange-500/20'}`

    container.querySelector('[data-transaction-type]').textContent = isReceived ? 'Received' : 'Sent'
    container.querySelector('[data-transaction-address]').textContent = shortAddress

    const valueEl = container.querySelector('[data-transaction-value]')
    valueEl.textContent = `${isReceived ? '+' : '-'}${parseFloat(value).toFixed(4)} ETH`
    valueEl.className = `text-sm font-mono font-semibold ${isReceived ? 'text-green-500' : 'text-orange-500'}`

    container.querySelector('[data-transaction-date]').textContent = `${date} ${time}`

    const link = container.querySelector('[data-transaction-link]')
    link.href = `https://etherscan.io/tx/${txHash}`
    container.querySelector('[data-transaction-hash]').textContent = shortHash

    return template
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
