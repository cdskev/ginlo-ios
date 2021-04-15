//
//  DPAGSimsMeBackgroundsViewController.swift
//  SIMSme
//
//  Created by RBU on 26/10/15.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import AVFoundation
import MobileCoreServices
import SIMSmeCore
import UIKit

class DPAGSimsMeBackgroundsViewController: DPAGViewControllerBackground {
    private let layout = UICollectionViewFlowLayout()
    private lazy var collectionView: UICollectionView = UICollectionView(frame: .zero, collectionViewLayout: self.layout)

    private lazy var numberFormatter: NumberFormatter = {
        let numberFormatter = NumberFormatter()

        numberFormatter.numberStyle = .decimal
        numberFormatter.minimumIntegerDigits = 2

        return numberFormatter
    }()

    private var customBackgroundImage: UIImage?
    private var customBackgroundImageLS: UIImage?

    private lazy var defaultBackgroundImage: UIImage? = {
        let width = (self.view.frame.size.width - 6) / 3
        let height = ((width / 100) * 177)
        return UIImage.image(size: CGSize(width: width, height: height), color: DPAGColorProvider.shared[.chatDetailsBackground])
    }()

    private lazy var defaultBackgroundImageLS: UIImage? = {
        let width = (self.view.frame.size.width - 6) / 3
        let height = ((width / 177) * 100)
        return UIImage.image(size: CGSize(width: width, height: height), color: DPAGColorProvider.shared[.chatDetailsBackground])
    }()

    private lazy var defaultBackgroundImage2: UIImage? = {
        let width = (self.view.frame.size.width - 6) / 3
        let height = ((width / 100) * 177)
        return UIImage.image(size: CGSize(width: width, height: height), color: DPAGColorProvider.shared[.chatDetailsBackground2])
    }()

    private lazy var defaultBackgroundImage2LS: UIImage? = {
        let width = (self.view.frame.size.width - 6) / 3
        let height = ((width / 177) * 100)
        return UIImage.image(size: CGSize(width: width, height: height), color: DPAGColorProvider.shared[.chatDetailsBackground2])
    }()

    init() {
        super.init(nibName: nil, bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        self.setupCustomBackgroundImage()
        self.setUpGui()
    }

    private func setupCustomBackgroundImage() {
        var customBackgroundImage: UIImage?

        if let imagePath = UserDefaults.standard.object(forKey: DPAGStrings.SIMS_CHAT_BACKGROUND_IMAGE_PATH) as? String {
            customBackgroundImage = DPAGUIHelper.backgroundImage(imagePath: imagePath)
        }

        self.customBackgroundImage = customBackgroundImage

//        var customBackgroundImageLS: UIImage
//
//        if let imagePathLS = UserDefaults.standard.object(forKey: DPAGStrings.SIMS_CHAT_BACKGROUND_IMAGE_PATH_LS) as? String
//        {
//            customBackgroundImageLS = DPAGChatStreamBaseViewController.backgroundImage(imagePath: imagePathLS)
//        }
//
//        self.customBackgroundImageLS = customBackgroundImageLS
    }

    private func setUpGui() {
        var constraints: [NSLayoutConstraint] = []

        self.title = DPAGLocalizedString("settings.preferences.changeBackgrounds.backgroundPresets")

        self.collectionView.dataSource = self
        self.collectionView.delegate = self

        self.collectionView.register(DPAGApplicationFacadeUISettings.cellBackgroundsNib(), forCellWithReuseIdentifier: "backgroundImageCell")
        self.collectionView.backgroundColor = .clear

        self.collectionView.translatesAutoresizingMaskIntoConstraints = false

        let stackView = UIStackView()

        stackView.axis = .vertical
        stackView.distribution = .fill
        stackView.alignment = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false

        self.view.addSubview(stackView)

        constraints += self.view.constraintsFill(subview: stackView)

        let viewButton = DPAGButtonPrimaryView()

        viewButton.translatesAutoresizingMaskIntoConstraints = false

        viewButton.button.setTitle(DPAGLocalizedString("chats.addAttachment.fromAlbum"), for: .normal)
        viewButton.button.addTargetClosure { [weak self] _ in

            let libraryUI = DPAGImagePickerController()

            libraryUI.setup()
            libraryUI.sourceType = .photoLibrary
            libraryUI.mediaTypes = [String(kUTTypeImage)]
            libraryUI.delegate = self

            self?.present(libraryUI, animated: true, completion: nil)
        }

        stackView.addArrangedSubview(self.collectionView)
        stackView.addArrangedSubview(viewButton)

        NSLayoutConstraint.activate(constraints)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        coordinator.animate(alongsideTransition: { [weak self] _ in

            self?.collectionView.collectionViewLayout.invalidateLayout()
        }, completion: nil)
    }
}

// MARK: - CollectionView Data Source

extension DPAGSimsMeBackgroundsViewController: UICollectionViewDataSource {
    func collectionView(_: UICollectionView, numberOfItemsInSection _: Int) -> Int {
        12
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cellDequeued = collectionView.dequeueReusableCell(withReuseIdentifier: "backgroundImageCell", for: indexPath)

        guard let cell = cellDequeued as? (UICollectionViewCell & DPAGBackgroundsCollectionViewCellProtocol) else { return cellDequeued }

        if indexPath.row < 2 {
            if indexPath.row == 0 {
//                cell.imageViewBackgroundLandscape?.image = self.defaultBackgroundImageLS
                cell.configure(with: self.defaultBackgroundImage, animate: false)
                cell.isSelected = self.customBackgroundImage == nil

                if cell.isSelected {
                    DispatchQueue.main.async {
                        collectionView.selectItem(at: indexPath, animated: true, scrollPosition: UICollectionView.ScrollPosition())
                    }
                }
            } else if indexPath.row == 1 {
                if self.customBackgroundImage != nil {
//                    cell.imageViewBackgroundLandscape?.image = self.customBackgroundImageLS
                    cell.configure(with: self.customBackgroundImage, animate: false)
                    cell.isSelected = true

                    DispatchQueue.main.async {
                        collectionView.selectItem(at: indexPath, animated: true, scrollPosition: UICollectionView.ScrollPosition())
                    }
                } else {
//                    cell.imageViewBackgroundLandscape?.image = self.defaultBackgroundImage2LS
                    cell.configure(with: self.defaultBackgroundImage2, animate: false)
                    cell.isSelected = false
                }
            }
        } else if let imageNum = self.numberFormatter.string(from: NSNumber(value: indexPath.row - 1)) {
            let imageName = String(format: UIImage.kImageBackgroundFormatPT, imageNum)
//            let imageNameLS = String(format: UIImage.kImageBackgroundFormatLS, imageNum)

//            cell.imageViewBackgroundLandscape?.image = nil
            cell.configure(with: nil, animate: true)
            cell.isSelected = false

            self.performBlockInBackground { [weak self, weak cell] in

//                let imageLS = UIImage(named: imageNameLS, in: Bundle(for: DPAGSimsMeBackgroundsViewController.self), compatibleWith: nil)
                let image = UIImage(named: imageName, in: Bundle(for: DPAGSimsMeBackgroundsViewController.self), compatibleWith: nil)

                self?.performBlockOnMainThread { [weak cell] in

//                    cell?.imageViewBackgroundLandscape?.image = imageLS
                    cell?.configure(with: image, animate: false)
                }
            }
            cell.isSelected = false
        }

//        let isLandscape = (collectionView.frame.size.width > collectionView.frame.size.height)

//        cell.imageViewBackgroundLandscape?.alpha = isLandscape ? 1 : 0
//        cell.imageViewBackground?.alpha = isLandscape ? 0 : 1

        cell.accessibilityIdentifier = "cell-\(indexPath.section)-\(indexPath.row)"

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout _: UICollectionViewLayout, sizeForItemAt _: IndexPath) -> CGSize {
        let width = (collectionView.frame.size.width - 6) / 3
        let height = collectionView.frame.size.width > collectionView.frame.size.height ? ((width / 177) * 100) : ((width / 100) * 177)

        return CGSize(width: width, height: height)
    }

    func collectionView(_: UICollectionView, layout _: UICollectionViewLayout, minimumLineSpacingForSectionAt _: Int) -> CGFloat {
        3
    }

    func collectionView(_: UICollectionView, layout _: UICollectionViewLayout, minimumInteritemSpacingForSectionAt _: Int) -> CGFloat {
        3
    }
}

// MARK: - CollectionView Delegate

extension DPAGSimsMeBackgroundsViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.row < 2 {
            if indexPath.row == 0 {
                UserDefaults.standard.removeObject(forKey: DPAGStrings.SIMS_CHAT_BACKGROUND_IMAGE_PATH)
                UserDefaults.standard.removeObject(forKey: DPAGStrings.SIMS_CHAT_BACKGROUND_IMAGE_PATH_LS)
                UserDefaults.standard.synchronize()
            } else {
                if let image = self.customBackgroundImage {
                    self.didSelectImage(image, imageLandscape: self.customBackgroundImageLS, from: self.navigationController, fromAlbum: false)
                } else if let image = self.defaultBackgroundImage2 {
                    self.didSelectImage(image, imageLandscape: self.defaultBackgroundImage2LS, from: self.navigationController, fromAlbum: false)
                }
            }
        } else if let imageNum = self.numberFormatter.string(from: NSNumber(value: indexPath.row - 1)) {
            let imageName = String(format: UIImage.kImageBackgroundFormatPT, imageNum)
            let imageNameLS = String(format: UIImage.kImageBackgroundFormatLS, imageNum)

            if let background = UIImage(named: imageName, in: Bundle(for: type(of: self)), compatibleWith: nil) {
                let backgroundLS = UIImage(named: imageNameLS, in: Bundle(for: type(of: self)), compatibleWith: nil)

                self.didSelectImage(background, imageLandscape: backgroundLS, from: self.navigationController, fromAlbum: false)
            }
        }
    }

    func collectionView(_: UICollectionView, didDeselectItemAt _: IndexPath) {
        UserDefaults.standard.removeObject(forKey: DPAGStrings.SIMS_CHAT_BACKGROUND_IMAGE_PATH)
        UserDefaults.standard.removeObject(forKey: DPAGStrings.SIMS_CHAT_BACKGROUND_IMAGE_PATH_LS)
        UserDefaults.standard.synchronize()
    }
}

extension DPAGSimsMeBackgroundsViewController: UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        guard let choosenImage = info[.originalImage] as? UIImage else {
            picker.dismiss(animated: true, completion: nil)
            return
        }

        let adjustChatBackgroundViewController = DPAGApplicationFacadeUISettings.adjustChatBackgroundVC(image: choosenImage, imageLandscape: nil, delegate: self)
        picker.pushViewController(adjustChatBackgroundViewController, animated: true)
        adjustChatBackgroundViewController.navigationController?.isNavigationBarHidden = false
    }
}

extension DPAGSimsMeBackgroundsViewController: DPAGAdjustChatBackgroundDelegate {
    func didSelectImage(_ image: UIImage, imageLandscape: UIImage?, from controller: UINavigationController?, fromAlbum: Bool) {
        if controller == self.navigationController {
            _ = self.navigationController?.popToViewController(self, animated: true)
        } else {
            controller?.dismiss(animated: true, completion: {})
        }
        guard let documentsDirectory = DPAGConstantsGlobal.documentsDirectory, let imageData = image.jpegData(compressionQuality: UIImage.compressionQualityDefault) else {
            self.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: "settings.preferences.changeBackground.error"))
            return
        }
        let imageName = "background@2x"
        let backgroundImageURL = URL(fileURLWithPath: documentsDirectory).appendingPathComponent(imageName).appendingPathExtension("png")
        do {
            try imageData.write(to: backgroundImageURL, options: [])
            UserDefaults.standard.set(imageName, forKey: DPAGStrings.SIMS_CHAT_BACKGROUND_IMAGE_PATH)
            UserDefaults.standard.synchronize()
            if let imageLandscape = imageLandscape {
                let imageNameLS = "background_ls@2x"
                let backgroundImageURLLS = URL(fileURLWithPath: documentsDirectory).appendingPathComponent(imageNameLS).appendingPathExtension("png")
                if let imageDataLS = imageLandscape.jpegData(compressionQuality: UIImage.compressionQualityDefault) {
                    do {
                        try imageDataLS.write(to: backgroundImageURLLS, options: [])
                        UserDefaults.standard.set(imageNameLS, forKey: DPAGStrings.SIMS_CHAT_BACKGROUND_IMAGE_PATH_LS)
                        UserDefaults.standard.synchronize()
                        if fromAlbum {
                            self.setupCustomBackgroundImage()
                            self.collectionView.reloadData()
                        }
                    } catch {
                        self.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: "settings.preferences.changeBackground.error"))
                    }
                } else {
                    self.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: "settings.preferences.changeBackground.error"))
                }
            } else {
                UserDefaults.standard.removeObject(forKey: DPAGStrings.SIMS_CHAT_BACKGROUND_IMAGE_PATH_LS)
                UserDefaults.standard.synchronize()
                if fromAlbum {
                    self.setupCustomBackgroundImage()
                    self.collectionView.reloadData()
                }
            }
        } catch {
            self.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: "settings.preferences.changeBackground.error"))
        }
    }
}
