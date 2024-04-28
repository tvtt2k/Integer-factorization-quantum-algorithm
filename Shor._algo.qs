namespace Shor_algo {

    open Microsoft.Quantum.Diagnostics;
    open Microsoft.Quantum.Arrays;
    open Microsoft.Quantum.Canon;
    open Microsoft.Quantum.Convert;
    open Microsoft.Quantum.Intrinsic;
    open Microsoft.Quantum.Math;
    open Microsoft.Quantum.Measurement;
    open Microsoft.Quantum.Unstable.Arithmetic;

    operation E01_QFT (register : Qubit[]) : Unit is Adj + Ctl {

        let n = Length(register) - 1;

        for idx in 0..n {        // Apply the Hadamard gate to the current qubit
            H(register[idx]);

            for j in 2..(n - idx + 1) {
                
                Controlled R1Frac([register[idx]], (2, j, register[idx + j - 1] ));
            }
            //reversal taking place here 
        }
        for i in 0 .. (Length(register)/2 - 1) {
            SWAP(register[i],register[Length(register) - i - 1]);
        }
    }


    operation ModularMultiplyByConstant(modulus : Int, c : Int, y : Qubit[])
    : Unit is Adj + Ctl {
        use qs = Qubit[Length(y)];
        for idx in IndexRange(y) {
            let shiftedC = (c <<< idx) % modulus;
            Controlled ModularAddConstant(
                [y[idx]],
                (modulus, shiftedC, qs));
        }
        for idx in IndexRange(y) {
            SWAP(y[idx], qs[idx]);
        }
        let invC = InverseModI(c, modulus);
        for idx in IndexRange(y) {
            let shiftedC = (invC <<< idx) % modulus;
            Controlled ModularAddConstant(
                [y[idx]],
                (modulus, modulus - shiftedC, qs));
        }
    }



    operation ModularAddConstant(modulus : Int, c : Int, y : Qubit[])
    : Unit is Adj + Ctl {
        body (...) {
            Controlled ModularAddConstant([], (modulus, c, y));
        }
        controlled (ctrls, ...) {

            if Length(ctrls) >= 2 {
                use control = Qubit();
                within {
                    Controlled X(ctrls, control);
                } apply {
                    Controlled ModularAddConstant([control], (modulus, c, y));
                }
            } else {
                use carry = Qubit();
                Controlled IncByI(ctrls, (c, y + [carry]));
                Controlled Adjoint IncByI(ctrls, (modulus, y + [carry]));
                Controlled IncByI([carry], (modulus, y));
                Controlled ApplyIfLessOrEqualL(ctrls, (X, IntAsBigInt(c), y, carry));
            }
        }
    }



    operation E01_ModExp (
        a : Int,
        b : Int,
        input : Qubit[],
        output : Qubit[]
    ) : Unit {


        // TODO a is base b is modulus
        let len = Length(input);
        X(output[Length(output)-1]);
        for i in 0 .. len - 1 {
            let rev = (len-1) -i;
            let exp = ExpModI(a, 2^rev, b);
            Controlled ModularMultiplyByConstant(
                [input[i]],
                (b,exp,output));    
        }  
    }


    operation E02_FindApproxPeriod (
        numberToFactor : Int,
        guess : Int
    ) : (Int, Int) {

        // TODO
        let logN = Lg(IntAsDouble(numberToFactor+1));
        
        let numQubits = Ceiling(logN);
        use inputRegister =  Qubit[numQubits*2];
        use outputRegister = Qubit[numQubits];
        
        ApplyToEachA(H,inputRegister);
        E01_ModExp(guess,numberToFactor,inputRegister,outputRegister);
        Adjoint E01_QFT(inputRegister);
       let measuredValue = MeasureInteger(inputRegister);
       let sizeOfInputSpace = 2 ^ (numQubits^2);
       let resultTuple = (measuredValue, sizeOfInputSpace);
       ResetAll(inputRegister);
       ResetAll(outputRegister);
       Message("resultTuple:"+$"{resultTuple}");
       return resultTuple;
        
    
    }

    function E03_FindPeriodCandidate (
        numerator : Int,
        denominator : Int,
        denominatorThreshold : Int
    ) : (Int, Int) {
        // TODO"

        mutable num = numerator;
        mutable den = denominator;
        mutable p = [0, 1];
        mutable q = [1, 0];
        mutable convergent = (0,1);
        mutable flag =1;
        
        for i in 2..denominatorThreshold{
            while(flag!=0){
                let ai = num / den;
                Message("ai"+$"{ai}");
                let rem = num % den;
                Message("rem"+$"{rem}");
                set p += [p[Length(p)-2] + p[Length(p)-1] * ai];
                Message("p"+$"{q}");
                set q += [q[Length(q)-2] + q[Length(q)-1] * ai];
                Message("q"+ $"{q}");
                
                let(_, highestdenoom) = convergent;
                if((q[Length(q)-1])<denominatorThreshold and (q[Length(q)-1])>highestdenoom){
                    set convergent = (p[Length(p)-1],q[Length(q)-1]);
                }
                if(rem!=0){
                set num = den;
                set den = rem;
                }
                set flag = rem;
                
            }
            // goal return highest convergent
             Message("conv:"+$"{convergent}");
            return convergent;
            
        }
    }



    operation E04_FindPeriod (numberToFactor : Int, guess : Int) : Int
    {

        let (num,den)= E02_FindApproxPeriod(numberToFactor,guess);
        Message("after we do E02 in E04 :"+$"{(num,den)}");
        let num_qt = Lg(IntAsDouble(den));
        let den_threshold = Ceiling(num_qt) + 3;
        let(num1,dum1)=E03_FindPeriodCandidate(num,den,den_threshold);
        Message("king:"+$"{dum1}");

        return dum1;
    }


    function E05_FindFactor (
        numberToFactor : Int,
        guess : Int,
        period : Int
    ) : Int {
        // TODO
        if(period%2==1){
            return -1;
        }
        let num_1 = GreatestCommonDivisorI(guess^(period/2)+1,numberToFactor);
        let num_2= GreatestCommonDivisorI(guess^(period/2)-1,numberToFactor);
        if(num_1!=numberToFactor and num_1!=1){
            return num_1; 
        }
        if(num_2!=numberToFactor and num_2!=1){
            return num_2; 
        }
        return -2;
    }
}
