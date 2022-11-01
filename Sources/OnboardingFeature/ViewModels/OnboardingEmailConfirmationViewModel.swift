import UIKit
import Models
import Shared
import Combine
import Defaults
import InputField
import XXClient
import CombineSchedulers
import DependencyInjection
import XXMessengerClient

struct OnboardingEmailConfirmationViewState: Equatable {
  var input: String = ""
  var status: InputField.ValidationStatus = .unknown(nil)
  var resendDebouncer: Int = 0
}

final class OnboardingEmailConfirmationViewModel {
  @Dependency var messenger: Messenger
  @Dependency var hudController: HUDController
  
  @KeyObject(.email, defaultValue: nil) var email: String?
  
  var completionPublisher: AnyPublisher<AttributeConfirmation, Never> { completionRelay.eraseToAnyPublisher() }
  private let completionRelay = PassthroughSubject<AttributeConfirmation, Never>()
  
  var timer: Timer?
  let confirmation: AttributeConfirmation
  
  var state: AnyPublisher<OnboardingEmailConfirmationViewState, Never> { stateRelay.eraseToAnyPublisher() }
  private let stateRelay = CurrentValueSubject<OnboardingEmailConfirmationViewState, Never>(.init())
  
  var backgroundScheduler: AnySchedulerOf<DispatchQueue> = DispatchQueue.global().eraseToAnyScheduler()
  
  init(_ confirmation: AttributeConfirmation) {
    self.confirmation = confirmation
    didTapResend()
  }
  
  func didInput(_ string: String) {
    stateRelay.value.input = string
    validate()
  }
  
  func didTapResend() {
    guard stateRelay.value.resendDebouncer == 0 else { return }
    
    stateRelay.value.resendDebouncer = 60
    
    timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) {  [weak self] in
      guard let self = self, self.stateRelay.value.resendDebouncer > 0 else {
        $0.invalidate()
        return
      }
      
      self.stateRelay.value.resendDebouncer -= 1
    }
  }
  
  func didTapNext() {
    hudController.show()
    
    backgroundScheduler.schedule { [weak self] in
      guard let self = self else { return }
      
      do {
        try self.messenger.ud.get()!.confirmFact(
          confirmationId: self.confirmation.confirmationId!,
          code: self.stateRelay.value.input
        )
        
        self.email = self.confirmation.content
        
        self.timer?.invalidate()
        self.hudController.dismiss()
        self.completionRelay.send(self.confirmation)
      } catch {
        let xxError = CreateUserFriendlyErrorMessage.live(error.localizedDescription)
        self.hudController.show(.init(content: xxError))
      }
    }
  }
  
  private func validate() {
    switch Validator.code.validate(stateRelay.value.input) {
    case .success:
      stateRelay.value.status = .valid(nil)
    case .failure(let error):
      stateRelay.value.status = .invalid(error)
    }
  }
}
