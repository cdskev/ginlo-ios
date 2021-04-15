//
//  SettingsProfileCell.swift
//  SIMSmeUISettingsLib
//

protocol SettingsProfileCellProtocol {
    var profileImageView: UIImageView! { get set }
    var nameLabel: UILabel! { get set }
    var accountDetailsLabel: UILabel! { get set }
}

class SettingsProfileCell: UITableViewCell, SettingsProfileCellProtocol {
    @IBOutlet var profileImageView: UIImageView!
    @IBOutlet var nameLabel: UILabel!
    @IBOutlet var accountDetailsLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        self.setSelectionColor()
    }
}
