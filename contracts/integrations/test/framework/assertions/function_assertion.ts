import { ContractFunctionObj, ContractTxFunctionObj } from '@0x/base-contract';
import { TransactionReceiptWithDecodedLogs } from 'ethereum-types';
import * as _ from 'lodash';

// tslint:disable:max-classes-per-file

export type GenericContractFunction<T> = (...args: any[]) => ContractFunctionObj<T>;

export interface FunctionResult {
    data?: any;
    success: boolean;
    receipt?: TransactionReceiptWithDecodedLogs;
}

/**
 * This interface represents a condition that can be placed on a contract function.
 * This can be used to represent the pre- and post-conditions of a "Hoare Triple" on a
 * given contract function. The "Hoare Triple" is a way to represent the way that a
 * function changes state.
 * @param before A function that will be run before a call to the contract wrapper
 *               function. Ideally, this will be a "precondition."
 * @param after A function that will be run after a call to the contract wrapper
 *              function.
 */
export interface Condition<TBefore> {
    before: (...args: any[]) => Promise<TBefore>;
    after: (beforeInfo: TBefore, result: FunctionResult, ...args: any[]) => Promise<any>;
}

/**
 * The basic unit of abstraction for testing. This just consists of a command that
 * can be run. For example, this can represent a simple command that can be run, or
 * it can represent a command that executes a "Hoare Triple" (this is what most of
 * our `Assertion` implementations will do in practice).
 * @param runAsync The function to execute for the assertion.
 */
export interface Assertion {
    executeAsync: (...args: any[]) => Promise<any>;
}

export interface AssertionResult<TBefore = unknown> {
    beforeInfo: TBefore;
    afterInfo: any;
}

/**
 * This class implements `Assertion` and represents a "Hoare Triple" that can be
 * executed.
 */
export class FunctionAssertion<TBefore, ReturnDataType> implements Assertion {
    // A condition that will be applied to `wrapperFunction`.
    public condition: Condition<TBefore>;

    // The wrapper function that will be wrapped in assertions.
    public wrapperFunction: (
        ...args: any[] // tslint:disable-line:trailing-comma
    ) => ContractTxFunctionObj<ReturnDataType> | ContractFunctionObj<ReturnDataType>;

    constructor(
        wrapperFunction: (
            ...args: any[] // tslint:disable-line:trailing-comma
        ) => ContractTxFunctionObj<ReturnDataType> | ContractFunctionObj<ReturnDataType>,
        condition: Partial<Condition<TBefore>> = {},
    ) {
        this.condition = {
            before: _.noop.bind(this),
            after: _.noop.bind(this),
            ...condition,
        };
        this.wrapperFunction = wrapperFunction;
    }

    /**
     * Runs the wrapped function and fails if the before or after assertions fail.
     * @param ...args The args to the contract wrapper function.
     */
    public async executeAsync(...args: any[]): Promise<AssertionResult<TBefore>> {
        // Call the before condition.
        const beforeInfo = await this.condition.before(...args);

        // Initialize the callResult so that the default success value is true.
        const callResult: FunctionResult = { success: true };

        // Try to make the call to the function. If it is successful, pass the
        // result and receipt to the after condition.
        try {
            const functionWithArgs = this.wrapperFunction(...args) as ContractTxFunctionObj<ReturnDataType>;
            callResult.data = await functionWithArgs.callAsync();
            callResult.receipt =
                functionWithArgs.awaitTransactionSuccessAsync !== undefined
                    ? await functionWithArgs.awaitTransactionSuccessAsync() // tslint:disable-line:await-promise
                    : undefined;
            // tslint:enable:await-promise
        } catch (error) {
            callResult.data = error;
            callResult.success = false;
            callResult.receipt = undefined;
        }

        // Call the after condition.
        const afterInfo = await this.condition.after(beforeInfo, callResult, ...args);

        return {
            beforeInfo,
            afterInfo,
        };
    }
}
