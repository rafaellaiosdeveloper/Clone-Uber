//
//  CadastroViewController.swift
//  Uber
//
//  Created by Rafaella Rodrigues Santos on 24/10/23.
//

import UIKit
import FirebaseAuth
import FirebaseDatabase

class CadastroViewController: UIViewController {
    
    @IBOutlet weak var email: UITextField!
    @IBOutlet weak var nomeCompleto: UITextField!
    @IBOutlet weak var senha: UITextField!
    @IBOutlet weak var tipoUsuario: UISwitch!

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.navigationController?.setNavigationBarHidden(false, animated: false)
    }
        
    @IBAction func cadastrarUsuario(_ sender: Any) {
        let retorno = self.validarCampos()
        if retorno == ""{
           
            //cadastrar usuario no firebase
            let autenticacao = Auth.auth()
            if let emailR = self.email.text{
                if let nomeR = self.nomeCompleto.text{
                    if let senhaR = self.senha.text {
                        autenticacao.createUser(withEmail: emailR , password: senhaR) { usuario, erro in
                            if erro == nil {
                                
                                //Valida se o usuário está logado
                                if usuario != nil {
                                    
                                    //Configura database
                                    let database = Database.database().reference()
                                    let usuarios = database.child("usuarios")
                                    
                                    //Verifica tipo do usuario
                                    var tipo = ""
                                    if self.tipoUsuario.isOn {//Passageiro
                                        tipo = "passageiro"
                                    }else{//Motorista
                                        tipo = "motorista"
                                    }
                                    
                                    //Salva no banco de dados do usuario
                                    let dadosUsuario = [
                                        "email" : usuario?.user.email ,
                                        "nome" : nomeR ,
                                        "tipo" : tipo
                                    ]
                                    
                                    //salvar dados
                                    usuarios.child(usuario!.user.uid).setValue(dadosUsuario)
                                
                                    //Valida se o usuário está logado
                                    
                                    //Caso o usuário esteja logado,será redirecionado automaticamente de acordo com o tipo de usuario com evento criado na ViewController
                                    
                                }else{
                                    print("Erro ao autenticar o usuário")
                                }
                            }else{
                                print("Erro ao criar conta do usuário, tente novamente!")
                            }
                        }
                    }
                }
            }
        }else{
            print("O campo \(retorno) não foi preenchido!")
        }
    }
    
    func validarCampos() -> String {
        if (self.email.text?.isEmpty)! {
            return "E-mail"
        }else if (self.nomeCompleto.text?.isEmpty)! {
            return "Nome completo"
        }else if (self.senha.text?.isEmpty)!{
            return "Senha"
        }
        return ""
    }
}
