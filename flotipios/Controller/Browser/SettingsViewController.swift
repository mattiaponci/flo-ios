//
//  SettingsViewController.swift
//  flotipios
//
//  Created by mattia poncini on 30.09.2024.
//

import SafariServices
import UIKit
import Firebase

class SettingsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    private let tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .grouped)
        table.register(UITableViewCell.self,
                       forCellReuseIdentifier: "cell")
        return table
    }()

    private var sections: [SettingsSection] = []

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Settings"
        view.addSubview(tableView)
        configureModels()
        tableView.delegate = self
        tableView.dataSource = self
        view.backgroundColor = .systemBackground
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(didTapClose)
        )
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = view.bounds
    }
    
    @objc func didTapClose() {
        dismiss(animated: true, completion: nil)
    }

    private func configureModels() {


        sections.append(
            SettingsSection(title: "Information", options: [
                SettingOption(
                    title: "Terms of Service",
                    image: UIImage(systemName: "doc"),
                    color: .systemPink
                ) { [weak self] in
                    DispatchQueue.main.async {
                        guard let url = URL(string: "https://www.flotip.com/terms.html") else {
                            return
                        }
                        let vc = SFSafariViewController(url: url)
                        self?.present(vc, animated: true, completion: nil)
                    }
                },
                SettingOption(
                    title: "Privacy Policy",
                    image: UIImage(systemName: "hand.raised"),
                    color: .systemGreen
                ) { [weak self] in
                    guard let url = URL(string: "https://help.instagram.com/519522125107875") else {
                        return
                    }
                    let vc = SFSafariViewController(url: url)
                    self?.present(vc, animated: true, completion: nil)

                },
              
            ])
        )
        sections.append(
                 SettingsSection(title: "Account", options: [
                     SettingOption(
                         title: "Logout",
                         image: UIImage(systemName: "arrow.turn.up.left"),
                         color: .systemRed
                     ) { [weak self] in
                         self?.handleLogout()
                     }
                 ])
             )
    }

    // Table

    private func handleLogout() {
           let actionSheet = UIAlertController(title: "Logout", message: "Are you sure you want to logout?", preferredStyle: .actionSheet)
           actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
           actionSheet.addAction(UIAlertAction(title: "Logout", style: .destructive, handler: { _ in
               do {
                 //  try Auth.auth().signOut()
                   // Reindirizzare all'interfaccia di login dopo il logout
                   // Questo dipende dalla configurazione del tuo storyboard o della navigazione programmata
                   
                      
                               try Auth.auth().signOut()
                               let loginVC = LoginVC()
                               let navController = UINavigationController(rootViewController: loginVC)
                               
                               // UPDATE: - iOS 13 presentation fix
                               navController.modalPresentationStyle = .fullScreen
                               
                               self.present(navController, animated: true, completion: nil)
                         
                       
                   
                   
                   
                   
                   
                   
               } catch let signOutError as NSError {
                   print("Error signing out: %@", signOutError)
               }
           }))
           present(actionSheet, animated: true)
       }

    @objc func didTapSignOut() {
      
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].options.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let model = sections[indexPath.section].options[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = model.title
        cell.imageView?.image = model.image
        cell.imageView?.tintColor = model.color
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let model = sections[indexPath.section].options[indexPath.row]
        model.handler()
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].title
    }
}
