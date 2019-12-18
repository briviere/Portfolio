//
//  PortfolioViewController.swift
//  Portfolio
//
//  Created by John Woolsey on 1/26/16.
//  Copyright © 2016 ExtremeBytes Software. All rights reserved.
//


import UIKit


class PortfolioViewController: UICollectionViewController {
    
    // MARK: - Enumerations
    
    private enum SelectedTextField: Int {
        case undefined, symbol, shares
        
        var identifier: Int {
            return rawValue
        }
    }
    
    
    // MARK: - Properties
    
    private let positionCellIdentifier = String(describing: PositionCollectionViewCell.self)
    private let positionsHeaderIdentifier = String(describing: PositionCollectionViewHeader.self)
    private let savedPortfolioSymbolsIdentifier = "SavedPortfolioSymbols"
    private let savedPortfolioSharesIdentifier = "SavedPortfolioShares"
    private let savedWatchListSymbolsIdentifier = "SavedWatchListSymbols"
    private let positionDeletionGestureRecognizer = UITapGestureRecognizer()
    
    private var symbols: [String] = []
    private var positions: [String: Position] = [:]
    private var shares: [String: Double] = [:]
    private var editingHeaderView: PositionCollectionViewHeader?
    private var refreshButton = UIBarButtonItem()
    private var visibleDetailViewController: PositionViewController?
    private var visibleAlertController: UIAlertController?
    private var visibleAlertSymbol: String?
    
    private var controllerType: PositionMemberType {
        if title == PositionMemberType.portfolio.title {
            return .portfolio
        }
        return .watchList
    }
    
    private var savedSymbols: [String] {
        let defaults = UserDefaults.standard
        switch controllerType {
        case .portfolio:
            return defaults.object(forKey: savedPortfolioSymbolsIdentifier) as? [String] ?? []
        case .watchList:
            return defaults.object(forKey: savedWatchListSymbolsIdentifier) as? [String] ?? []
        }
        //      return ["NNNN", "AAPL", "KO", "TSLA", "CSCO", "SHIP", "BND", "IBM"]  // MARK: Used for testing
    }
    private var savedShares: [String: Double] {
        let defaults = UserDefaults.standard
        switch controllerType {
        case .portfolio:
            return defaults.object(forKey: savedPortfolioSharesIdentifier) as? [String: Double] ?? [:]
        default:
            return [:]
        }
        //      return ["NNNN": 0, "AAPL": 90.8, "KO": 100.9, "TSLA": 101, "CSCO": 102.1, "SHIP": 88, "BND": 1000, "IBM": 80.8]  // MARK: Used for testing
    }
    private var editingHeaderViewOrigin: CGPoint {
        if let navigationBarFrame = navigationController?.navigationBar.frame {
            return CGPoint(x: view.safeAreaInsets.left, y: navigationBarFrame.origin.y + navigationBarFrame.size.height)
        } else {
            return CGPoint.zero
        }
    }
    private var editingHeaderViewSize: CGSize {
        return CGSize(width: view.safeAreaLayoutGuide.layoutFrame.width, height: 88)
    }
    
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.collectionView.contentInsetAdjustmentBehavior = .always
        configureNavigationBar()
        configureCollectionView()
        applyTheme()
        loadState()
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // TODO: Prefer to handle the following within viewWillAppear, but the view is not updated in time.
        if isEditing {
            editingHeaderView?.frame = CGRect(origin: editingHeaderViewOrigin, size: editingHeaderViewSize)
            updateCollectionViewFlowLayout()
        }
    }
    
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.updateCollectionViewFlowLayout()
            if self.isEditing {
                self.editingHeaderView?.frame = CGRect(origin: self.editingHeaderViewOrigin,
                                                       size: self.editingHeaderViewSize)
                if AppCoordinator.shared.deviceType == .pad,
                    let alertSymbol = self.visibleAlertSymbol,
                    let alertController = self.visibleAlertController {
                    // Dismiss and re-present alert controller to update popover location and arrow direction
                    alertController.dismiss(animated: true) {
                        self.requestDeletionConfirmationFromUser(for: alertSymbol)
                    }
                }
            } else if AppCoordinator.shared.deviceType == .pad,
                let detailViewController = self.visibleDetailViewController,
                detailViewController.isViewVisible,
                let localCollectionView = self.collectionView,
                let indexPath = localCollectionView.indexPathsForSelectedItems?.first {
                // Dismiss and re-present detail view controller to update popover location and arrow direction
                detailViewController.dismiss(animated: true) {
                    self.collectionView(localCollectionView, didSelectItemAt: indexPath)
                }
            }
        })
    }
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        if editing {
            enableEditing()
        } else {
            disableEditing()
        }
    }
    
    
    // MARK: - Actions
    
    /**
     Changes the application theme when the Action button is pressed.
     
     - parameter sender: The object that requested the action.
     */
    @objc func actionButtonPressed(_ sender: UIBarButtonItem) {
        if ThemeManager.currentTheme == .light {
            ThemeManager.applyTheme(.dark)
        } else {
            ThemeManager.applyTheme(.light)
        }
        applyTheme()
        
        // Reload views
        for window in UIApplication.shared.windows {
            for view in window.subviews {
                view.removeFromSuperview()
                window.addSubview(view)
            }
        }
    }
    
    
    /**
     Initiates a request to the user to add an investment position to the portfolio when the Add button is pressed.
     
     - parameter sender: The object that requested the action.
     */
    @objc func addButtonPressed(_ sender: UIBarButtonItem) {
        requestAdditionSymbolFromUser()
    }
    
    
    /**
     Initiates a request to the user to delete an investment position from the portfolio when a deletion gesture is recognized.
     
     - parameter sender: The object that requested the action.
     */
    @objc func positionDeletionRequested(_ sender: UITapGestureRecognizer) {
        let location = positionDeletionGestureRecognizer.location(in: collectionView)
        if let indexPath = collectionView?.indexPathForItem(at: location),
            let cell = collectionView?.cellForItem(at: indexPath) as? PositionCollectionViewCell,
            let symbol = cell.symbol {
            requestDeletionConfirmationFromUser(for: symbol)
        } else {
            AppCoordinator.shared.presentErrorToUser(title: "Deletion Error",
                                                     message: "Could not remove the selected investment position from the portfolio. Please try again.")
        }
    }
    
    
    /**
     Refreshes investment positions when the Refresh button is pressed.
     
     - parameter sender: The object that requested the action.
     */
    @objc func refreshButtonPressed(_ sender: UIBarButtonItem) {
        refreshState()
    }
    
    
    /**
     Enables refresh capability when the refresh timer is fired.
     
     - parameter sender: The object that requested the action.
     */
    @objc func refreshTimerFired(_ sender: Timer) {  // @objc required for recognizing method selector signature
        #if DEBUG
        print("Refresh timer fired.")
        #endif
        enableRefresh()
    }
    
    
    // MARK: - Configuration
    
    /**
     Applies view controller specific theming.
     */
    private func applyTheme() {
    }
    
    
    /**
     Configures the navigation bar.
     */
    private func configureNavigationBar() {
        refreshButton = UIBarButtonItem(barButtonSystemItem: .refresh,
                                        target: self,
                                        action: #selector(refreshButtonPressed(_:)))
        let themeButton = UIBarButtonItem(image: UIImage(named: "Switch"),
                                          style: .plain,
                                          target: self,
                                          action: #selector(actionButtonPressed(_:)))
        navigationItem.leftBarButtonItems = [refreshButton, themeButton]
        let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addButtonPressed(_:)))
        let editButton = editButtonItem
        navigationItem.rightBarButtonItems = [editButton, addButton]
    }
    
    
    /**
     Configures the portfolio collection view.
     */
    private func configureCollectionView() {
        installsStandardGestureForInteractiveMovement = false
        collectionView?.register(UINib(nibName: positionCellIdentifier, bundle: nil),
                                 forCellWithReuseIdentifier: positionCellIdentifier)
        updateCollectionViewFlowLayout()
        
        // Configure deletion gesture recognizer
        positionDeletionGestureRecognizer.numberOfTapsRequired = 2
        positionDeletionGestureRecognizer.addTarget(self, action: #selector(positionDeletionRequested(_:)))
    }
    
    
    /**
     Updates the portfolio collection view flow layout.
     */
    private func updateCollectionViewFlowLayout() {
        let spacerSize = PositionCoordinator.spacerSize
        let flowLayout = UICollectionViewFlowLayout()
        flowLayout.minimumInteritemSpacing = spacerSize.width
        flowLayout.minimumLineSpacing = spacerSize.height
        flowLayout.itemSize = PositionCoordinator.cellSizeFor(screenWidth: view.safeAreaLayoutGuide.layoutFrame.width,
                                                              positionType: controllerType)
        collectionView?.collectionViewLayout = flowLayout
    }
    
    
    // MARK: - Editing
    
    /**
     Enables editing of the portfolio.
     */
    private func enableEditing() {
        installsStandardGestureForInteractiveMovement = true
        
        // Create header view if necessary
        if editingHeaderView == nil {
            let nib = UINib(nibName: positionsHeaderIdentifier, bundle: nil)
            if let headerView = nib.instantiate(withOwner: PositionCollectionViewHeader(),
                                                options: nil).first as? PositionCollectionViewHeader {
                editingHeaderView = headerView
            }
        }
        
        // Display header view
        if let headerView = editingHeaderView,
            let contentInsetCurrent = collectionView?.contentInset {
            collectionView?.contentInset = UIEdgeInsets(top: contentInsetCurrent.top + editingHeaderViewSize.height,
                                                        left: 0, bottom: contentInsetCurrent.bottom, right: 0)
            headerView.frame = CGRect(origin: editingHeaderViewOrigin, size: editingHeaderViewSize)
            view.addSubview(headerView)
            editingHeaderView = headerView
        }
        
        collectionView?.addGestureRecognizer(positionDeletionGestureRecognizer)
    }
    
    
    /**
     Disables editing of the portfolio.
     */
    private func disableEditing() {
        installsStandardGestureForInteractiveMovement = false
        
        // Remove header view
        if let headerView = editingHeaderView,
            let contentInsetCurrent = collectionView?.contentInset {
            headerView.removeFromSuperview()
            collectionView?.contentInset = UIEdgeInsets(top: contentInsetCurrent.top - editingHeaderViewSize.height,
                                                        left: 0, bottom: contentInsetCurrent.bottom, right: 0)
        }
        
        collectionView?.removeGestureRecognizer(positionDeletionGestureRecognizer)
    }
    
    /**
     Adds a new investment postion to the portfolio.
     
     - parameter symbol: The ticker symbol of the investment position.
     */
    private func addPositionToPortfolio(for symbol: String?, shares: String? = nil) {
        // Validate input
        guard let symbol = symbol, !symbol.isEmpty else {
            AppCoordinator.shared.presentErrorToUser(title: "Invalid Ticker Symbol",
                                                     message: "The ticker symbol entered was invalid. Please try again.")
            return
        }
        
        guard symbols.contains(symbol) == false else {
            AppCoordinator.shared.presentErrorToUser(title: "Duplicate Ticker Symbol",
                                                     message: "The ticker symbol entered already exists.")
            return
        }
        
        var shareCount: Double = 0
        if controllerType == .portfolio {
            if let sharesString = shares,
                let sharesNumber = Double(sharesString),
                sharesNumber.isNormal,
                sharesNumber > 0 {
                shareCount = sharesNumber
            } else {
                AppCoordinator.shared.presentErrorToUser(title: "Invalid Share Count",
                                                         message: "The number of shares entered was invalid. Please try again.")
                return
            }
        }
        
        NetworkManager.shared.fetchPosition(for: symbol) { results, error in
            if let error = error {
                AppCoordinator.shared.presentErrorToUser(title: "Retrieval Error",
                                                         message: error.localizedDescription)
            } else if let results = results,  !symbol.isEmpty {
                let index = self.symbols.count
                
                if let data = results.data {
                    let decoder = JSONDecoder()
                    //decoder.keyDecodingStrategy = .convertFromSnakeCase
                    guard let positionsData = try? decoder.decode(PositionsData.self, from: data) else { return }
                    
                    print(positionsData)
                    
                    var position = self.setPosition(positionsData: positionsData)
                    
                    position.memberType = self.controllerType
                    
                    if self.controllerType == .portfolio {
                        self.shares[symbol] = shareCount
                        position.shares = shareCount
                    }
                    
                    self.positions[symbol] = position
                    
                    self.symbols.append(symbol)
                    
                    DispatchQueue.main.async {
                        self.collectionView?.insertItems(at: [IndexPath(item: index, section: 0)])
                        
                        self.collectionView?.scrollToItem(at: IndexPath(item: index, section: 0), at: .bottom, animated: true)
                    }
                    
                    self.saveState()
                }
                
            } else {
                AppCoordinator.shared.presentErrorToUser(title: "Creation Error",
                                                         message: "The investment position could not be created. Please try again.")
            }
        }
    }
    
    /***
     Set the Position to process.
     */
    private func setPosition(positionsData : PositionsData) -> Position {
        
        var position : Position = Position()
        
        position.status = "open"
        
        if let symbol = positionsData.data?[0].symbol {
            position.symbol = symbol
        }
        
        if let name = positionsData.data?[0].name {
            position.name = name
        }
        
        if let lastPrice = positionsData.data?[0].price {
            position.lastPrice = Double(lastPrice)
        }
        
        if let change = positionsData.data?[0].day_change {
            position.change = Double(change)
        }
        
        if let changePercent = positionsData.data?[0].change_pct {
            position.changePercent = Double(changePercent)
        }
        
        position.timeStamp = positionsData.data?[0].last_trade_time
        
        if let marketCap = positionsData.data?[0].market_cap {
            position.marketCap = Double(marketCap)
        }
        
        if let volume = positionsData.data?[0].volume {
            position.volume = Double(volume)
        }
        
        if let changeYTD = positionsData.data?[0].day_change {
            position.changeYTD = Double(changeYTD)
        }
        
        if let changePercentYTD = positionsData.data?[0].change_pct {
            position.changePercentYTD = Double(changePercentYTD)
        }
        
        if let high = positionsData.data?[0].day_high {
            position.high = Double(high)
        }
        
        if let low = positionsData.data?[0].day_low {
            position.low = Double(low)
        }
        
        if let open = positionsData.data?[0].price_open {
            position.open = Double(open)
        }
        
        return position
        
    }
    
    
    /**
     Deletes an investment position from the portfolio.
     
     - parameter symbol: The ticker symbol of the investment position.
     */
    private func deletePositionFromPortfolio(for symbol: String) {
        // Validate input
        guard !symbol.isEmpty && symbols.contains(symbol) != false else {
            AppCoordinator.shared.presentErrorToUser(title: "Invalid Ticker Symbol",
                                                     message: "The ticker symbol entered was invalid. Please try again.")
            return
        }
        
        // Remove position
        if let index = symbols.firstIndex(of: symbol) {
            positions[symbol] = nil
            shares[symbol] = nil
            symbols.remove(at: index)
            collectionView?.deleteItems(at: [IndexPath(item: index, section: 0)])
            saveState()
        } else {
            AppCoordinator.shared.presentErrorToUser(title: "Deletion Error",
                                                     message: "Could not remove the \(symbol) investment position from the portfolio. Please try again.")
        }
    }
    
    
    /**
     Presents a pop up window to the user requesting a ticker symbol for adding an investment postion to the portfolio.
     */
    private func requestAdditionSymbolFromUser() {
        // Present pop up symbol input view to user
        let alertController = UIAlertController(title: "Add Position",
                                                message: "Enter the information for the investment position you would like to add.",
                                                preferredStyle: .alert)
        let addAction = UIAlertAction(title: "Add", style: .default) { _ in
            let symbol = alertController.textFields?[0].text?.uppercased()
            switch self.controllerType {
            case .portfolio:
                let shares = alertController.textFields?[1].text
                self.addPositionToPortfolio(for: symbol, shares: shares)
            case .watchList:
                self.addPositionToPortfolio(for: symbol)
            }
        }
        alertController.addAction(addAction)
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        alertController.addAction(cancelAction)
        alertController.addTextField { textField in textField.placeholder = "ticker symbol" }
        if controllerType == .portfolio {
            alertController.addTextField { textField in
                textField.tag = SelectedTextField.shares.identifier
                textField.keyboardType = .numbersAndPunctuation
                textField.placeholder = "number of shares"
                textField.delegate = self
            }
        }
        present(alertController, animated: true)
        return
    }
    
    
    /**
     Presents a confirmation window to the user to confirm deletion of an investment postion from the portfolio.
     
     - parameter symbol: The ticker symbol of the investment position.
     */
    private func requestDeletionConfirmationFromUser(for symbol: String) {
        let alertController = UIAlertController(title: "Confirm Delete",
                                                message: "Are you sure you want to remove the \(symbol) investment position from the portfolio?",
            preferredStyle: .actionSheet)
        let deleteAction = UIAlertAction(title: "Delete", style: .destructive) { _ in
            self.visibleAlertController = nil
            self.visibleAlertSymbol = nil
            self.deletePositionFromPortfolio(for: symbol)
        }
        alertController.addAction(deleteAction)
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in
            self.visibleAlertController = nil
            self.visibleAlertSymbol = nil
        }
        alertController.addAction(cancelAction)
        
        // Apply as popover on iPad
        if AppCoordinator.shared.deviceType == .pad {
            alertController.modalPresentationStyle = .popover
            if let presenter = alertController.popoverPresentationController,
                let index = symbols.firstIndex(of: symbol),
                let cell = collectionView?.cellForItem(at: IndexPath(item: index, section: 0))
                    as? PositionCollectionViewCell {
                presenter.sourceView = cell
                presenter.sourceRect = cell.bounds
            }
            visibleAlertSymbol = symbol
            visibleAlertController = alertController
        }
        
        present(alertController, animated: true)
    }
    
    
    // MARK: - State
    
    /**
     Clears the current visible state of investment postions.
     */
    //   private func clearState() {
    //      symbols.removeAll()
    //      positions.removeAll()
    //      collectionView?.reloadData()
    //   }
    
    
    /**
     Loads the current visible state of investment positions.
     */
    private func loadState() {
        loadShares()
        loadPositions()
        disableRefresh()
    }
    
    
    /**
     Refreshes the current visible state of investment positions.
     */
    private func refreshState() {
        refreshPositions()
        disableRefresh()
    }
    
    
    /**
     Saves the current list of investment position symbols to the user defaults system.
     */
    private func saveState() {
        let defaults = UserDefaults.standard
        switch controllerType {
        case .portfolio:
            defaults.set(symbols, forKey: savedPortfolioSymbolsIdentifier)
            defaults.set(shares, forKey: savedPortfolioSharesIdentifier)
        case .watchList:
            defaults.set(symbols, forKey: savedWatchListSymbolsIdentifier)
        }
        defaults.synchronize()
    }
    
    
    // MARK: - Other
    
    /**
     Enables refresh capability.
     */
    private func enableRefresh() {
        refreshButton.isEnabled = true
    }
    
    
    /**
     Disables refresh capability for 1 minute.
     */
    private func disableRefresh() {
        refreshButton.isEnabled = false
        Timer.scheduledTimer(timeInterval: 60, target: self, selector: #selector(refreshTimerFired(_:)),
                             userInfo: nil, repeats: false)
    }
    
    
    /**
     Loads saved symbols and builds positions from the server.
     */
    private func loadPositions() {
        for symbol in savedSymbols {
            NetworkManager.shared.fetchPosition(for: symbol) { results, error in
                var newPosition: Position = Position()
                if let results = results {
                    if let data = results.data {
                        let decoder = JSONDecoder()
                        
                        //decoder.keyDecodingStrategy = .convertFromSnakeCase
                        guard let positionsData = try? decoder.decode(PositionsData.self, from: data) else { return }
                        
                        print(positionsData)
                        
                        let position = self.setPosition(positionsData: positionsData)
                        
                        newPosition = position
                        
                        newPosition.memberType = self.controllerType
                    }
                } else {
                    newPosition = self.defaultPosition(for: symbol)
                }
                
                if let shares = self.shares[symbol] {
                    newPosition.shares = shares
                }
                
                self.positions[symbol] = newPosition
                
                if let currentIndex = PositionCoordinator.insertionIndex(for: symbol,
                                                                         from: self.savedSymbols,
                                                                         into: self.symbols) {
                    self.symbols.insert(symbol, at: currentIndex)
                    
                    DispatchQueue.main.async {
                        self.collectionView?.insertItems(at: [IndexPath(item: currentIndex, section: 0)])
                    }
                }
                if let error = error {
                    AppCoordinator.shared.presentErrorToUser(title: "Retrieval Error",
                                                             message: error.localizedDescription)
                }
            }
        }
    }
    
    
    /**
     Loads saved shares.
     */
    private func loadShares() {
        shares = savedShares
    }
    
    
    /**
     Refreshes the positions from the server.
     */
    private func refreshPositions() {
        for symbol in symbols {
            NetworkManager.shared.fetchPosition(for: symbol) { results, _ in
                if let results = results {
                    if let data = results.data {
                        let decoder = JSONDecoder()
                        
                        //decoder.keyDecodingStrategy = .convertFromSnakeCase
                        guard let positionsData = try? decoder.decode(PositionsData.self, from: data) else { return }
                        
                        print(positionsData)
                        
                        let position:Position? = self.setPosition(positionsData: positionsData)
                        
                        if var newPosition = position,
                            newPosition.symbol == symbol,
                            let index = self.symbols.firstIndex(of: symbol) {
                            newPosition.memberType = self.controllerType
                            if let shares = self.shares[symbol] {
                                newPosition.shares = shares
                            }
                            self.positions[symbol] = newPosition
                            DispatchQueue.main.async {
                                self.collectionView?.reloadItems(at: [IndexPath(item: index, section: 0)])
                            }
                        }
                    }
                }
            }
        }
    }
    
    /**
     Creates and returns a simple default position.
     
     - parameter symbol: The investment position ticker symbol to apply if supplied.
     
     - returns: A default position.
     */
    private func defaultPosition(for symbol: String? = nil) -> Position {
        var position = Position()
        position.memberType = controllerType
        position.symbol = symbol
        return position
    }
    
    
    /**
     Returns a position for the specified symbol.
     
     - parameter symbol: The investment position ticker symbol.
     
     - returns: The saved position if found, otherwise a new default position.
     */
    private func savedPosition(for symbol: String) -> Position {
        guard !symbol.isEmpty else {
            return defaultPosition()
        }
        
        if let savedPosition = positions[symbol], savedPosition.symbol == symbol {
            return savedPosition
        } else {
            return defaultPosition(for: symbol)
        }
    }
}


// MARK: - UICollectionViewDataSource

extension PortfolioViewController {
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return symbols.count
    }
    
    
    override func collectionView(_ collectionView: UICollectionView,
                                 cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        // Get cell
        let baseCell = collectionView.dequeueReusableCell(withReuseIdentifier: positionCellIdentifier, for: indexPath)
        
        // Validate cell
        guard let cell = baseCell as? PositionCollectionViewCell else {
            return baseCell
        }
        
        // Get position
        let symbol = symbols[indexPath.item]
        let position = savedPosition(for: symbol)
        
        // Configure cell
        cell.configure(with: position)
        
        return cell
    }
    
    
    override func collectionView(_ collectionView: UICollectionView,
                                 moveItemAt sourceIndexPath: IndexPath,
                                 to destinationIndexPath: IndexPath) {
        let temp = symbols.remove(at: sourceIndexPath.item)
        symbols.insert(temp, at: destinationIndexPath.item)
        saveState()
    }
}


// MARK: - UICollectionViewDelegate

extension PortfolioViewController {
    
    override func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        return !isEditing
    }
    
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let symbol = symbols[indexPath.item]
        let detailViewController = PositionViewController()
        detailViewController.title = symbol
        detailViewController.position = savedPosition(for: symbol)
        
        // Present position detail view controller
        switch AppCoordinator.shared.deviceType {
        case .pad:  // apply as popover
            detailViewController.modalPresentationStyle = .popover
            if let presenter = detailViewController.popoverPresentationController,
                let cell = collectionView.cellForItem(at: indexPath) as? PositionCollectionViewCell {
                presenter.sourceView = cell
                presenter.sourceRect = cell.bounds
            }
            visibleDetailViewController = detailViewController
            present(detailViewController, animated: true)
        default:
            navigationController?.pushViewController(detailViewController, animated: true)
        }
    }
}


// MARK: - UITextFieldDelegate

extension PortfolioViewController: UITextFieldDelegate {
    
    func textField(_ textField: UITextField,
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {
        if textField.tag == SelectedTextField.shares.identifier {
            let invalidCharacters = CharacterSet(charactersIn: "0123456789.").inverted
            let filteredString = string.components(separatedBy: invalidCharacters).joined(separator: "")
            return string == filteredString
        } else {
            return true
        }
    }
    
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        return true
    }
}
