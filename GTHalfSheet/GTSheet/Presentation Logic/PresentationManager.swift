//
//  HalfSheetPresentationManager.swift
//  Gametime
//
//  Created by Matt Banach on 3/22/16.
//
//

import Foundation

public class HalfSheetPresentationManager: NSObject, UIGestureRecognizerDelegate {

    internal var interactive: Bool = false
    private var observer: NSKeyValueObservation?

    public private(set) lazy var dismissingPanGesture: VerticalPanGestureRecognizer = { [unowned self] in
        let gesture = VerticalPanGestureRecognizer()
        gesture.addTarget(self, action: #selector(HalfSheetPresentationManager.handleDismissingPan(_:)))
        return gesture
    }()

    public private(set) lazy var contentDismissingPanGesture: UIPanGestureRecognizer = { [unowned self] in
        let gesture = UIPanGestureRecognizer()
        gesture.addTarget(self, action: #selector(HalfSheetPresentationManager.handleDismissingPan(_:)))
        return gesture
    }()

    public private(set) lazy var backgroundViewDismissTrigger: UITapGestureRecognizer = { [unowned self] in
        let gesture = UITapGestureRecognizer()
        gesture.addTarget(self, action: #selector(HalfSheetPresentationManager.handleDismissingTap))
        return gesture
    }()

    fileprivate let presentationAnimation: PresentationAnimator
    fileprivate let dismissalAnimation: DismissalAnimator

    internal var presentationController: PresentationViewController?

    public override init() {

        presentationAnimation = PresentationAnimator()
        dismissalAnimation = DismissalAnimator()

        super.init()

        presentationAnimation.managerDelegate = self
        dismissalAnimation.managerDelegate = self
        dismissalAnimation.manager = self
    }

    //
    // MARK: Gesture Recoginzers
    //

    @objc func handleDismissingTap() {

        guard
            allowTapToDismiss,
            managedScrollView != nil ? managedScrollView?.isScrolling == false : true
        else {
            return
        }

        interactive = false
        presentationController?.presentedViewController.dismiss(animated: true)
    }

    @objc func handleDismissingPan(_ pan: UIPanGestureRecognizer) {

        guard
            allowTapToDismiss,
            managedScrollView != nil ? managedScrollView?.isScrolling == false : true
        else {
            return
        }

        let translation = pan.translation(in: pan.view!)
        let velocity    = pan.velocity(in: pan.view!)
        let sourceView  = pan.view

        interactive = true

        let d: CGFloat = max(translation.y, 0) / (sourceView?.bounds.height ?? 0.0)

        switch pan.state {
        case .began:
            guard velocity.y > 0 else { return }
            HapticHelper.warmUp()
            presentationController?.presentedViewController.dismiss(animated: true, completion:nil)
        case .changed:
            dismissalAnimation.update(d)

            if max(translation.y, 0) > TransitionConfiguration.Dismissal.dismissBreakpoint {
                interactive = false
                pan.isEnabled = false
                HapticHelper.impact()
                dismissalAnimation.finish()
            }
        default:
            interactive = false
            translation.y > TransitionConfiguration.Dismissal.dismissBreakpoint ? dismissalAnimation.finish() : dismissalAnimation.cancel()
        }
    }

    public func updateForScrollPosition(yOffset: CGFloat) {

        let fullOffset = yOffset + topOffset

        guard fullOffset < 0 else {
            return
        }

        let forwardTransform = CGAffineTransform(
            translationX: 0,
            y: -fullOffset
        )

        let backwardsTransform = CGAffineTransform(
            translationX: 0,
            y: fullOffset
        )

        presentationController?.wrappingView.layer.transform = forwardTransform.as3D

        if auxileryTransition?.isSlide == true {
            auxileryView?.transform = forwardTransform
        }

        presentationController?.managedScrollView?.layer.transform = backwardsTransform.as3D

        if -fullOffset > TransitionConfiguration.Dismissal.dismissBreakpoint {
            observer = nil
            interactive = false
            HapticHelper.impact()
            presentationController?.presentedViewController.dismiss(animated: true, completion:nil)
        }
    }

    internal func dismissComplete() {
        observer = nil
        (presentationController?.presentingViewController as? HalfSheetCompletionProtocol)?.didDismiss()
        presentationController = nil
    }
    
    public func didChangeSheetHeight() {
        presentationController?.updateSheetHeight()
    }

    private var allowSwipeToDismiss: Bool {
        return presentationController?.respondingVC?.dismissMethod.allowSwipe ?? false
    }

    private var allowTapToDismiss: Bool {
        return presentationController?.respondingVC?.dismissMethod.allowTap ?? false
    }

    private var topOffset: CGFloat {
        if #available(iOS 11.0, *) {
            return presentationController?.managedScrollView?.safeAreaInsets.top ?? 0.0
        } else {
            return presentationController?.managedScrollView?.contentInset.top ?? 0.0
        }
    }

    deinit {
        observer = nil
    }
}

extension HalfSheetPresentationManager: UIViewControllerTransitioningDelegate {

    public func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return presentationAnimation
    }

    public func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return dismissalAnimation
    }

    public func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        return interactive ? dismissalAnimation : nil
    }

    public func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {

        assert(presented.modalPresentationStyle == .custom, "you must use custom presentation style for half sheets (and any custom transition")

        presentationController = PresentationViewController(
            presentedViewController: presented, presenting: source
        )

        presentationController?.managerDelegate = self

        return presentationController
    }

    var managedScrollView: UIScrollView? {
        return presentationController?.managedScrollView
    }
}

extension UIScrollView {
    var isScrolling: Bool {
        return isDragging || isDecelerating
    }
}

extension HalfSheetPresentationManager: PresentationViewControllerDelegate {

    internal func didPresent() {

        guard let scrollView = presentationController?.managedScrollView else {
            return
        }

        observer = scrollView.observe(\UIScrollView.contentOffset, options: [.new]) { [weak self] _, change in
            if let offset = change.newValue, offset.y < 0 {
                self?.updateForScrollPosition(yOffset: offset.y)
            }
        }
    }

    internal var auxileryView: UIView? {
        return presentationController?.topVCProvider?.topVC.view
    }

    internal var auxileryTransition: HalfSheetTopVCTransitionStyle? {
        return presentationController?.topVCProvider?.topVCTransitionStyle
    }
}
