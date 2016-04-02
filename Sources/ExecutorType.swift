//
//  ExecutorType.swift
//  Deferred
//
//  Created by Zachary Waldowski on 3/29/16.
//  Copyright © 2014-2016 Big Nerd Ranch. All rights reserved.
//

public protocol ExecutorType {

    func submit(body: () -> Void)

}
