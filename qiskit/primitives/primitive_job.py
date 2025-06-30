# This code is part of Qiskit.
#
# (C) Copyright IBM 2022, 2024.
#
# This code is licensed under the Apache License, Version 2.0. You may
# obtain a copy of this license in the LICENSE.txt file in the root directory
# of this source tree or at http://www.apache.org/licenses/LICENSE-2.0.
#
# Any modifications or derivative works of this code must retain this
# copyright notice, and modified files need to carry a notice indicating
# that they have been altered from the originals.
"""
Job for the reference implementations of Primitives V1 and V2.
"""

import uuid
from concurrent.futures import Future

from qiskit.providers import JobError, JobStatus
from qiskit.providers.jobstatus import JOB_FINAL_STATES

from .base.base_primitive_job import BasePrimitiveJob, ResultT


class _SynchronousFuture:
    """A Future-like object that executes synchronously."""
    
    def __init__(self, func, *args, **kwargs):
        self._result = None
        self._exception = None
        self._done = False
        self._cancelled = False
        
        try:
            self._result = func(*args, **kwargs)
            self._done = True
        except Exception as e:
            self._exception = e
            self._done = True
    
    def result(self):
        if self._exception:
            raise self._exception
        return self._result
    
    def done(self):
        return self._done
    
    def running(self):
        return False  # Always False since we execute synchronously
    
    def cancelled(self):
        return self._cancelled
    
    def cancel(self):
        return False  # Can't cancel since execution is immediate
    
    def exception(self):
        return self._exception


class PrimitiveJob(BasePrimitiveJob[ResultT, JobStatus]):
    """
    Primitive job class for the reference implementations of Primitives.
    """

    def __init__(self, function, *args, **kwargs):
        """
        Args:
            function: A callable function to execute the job.
        """
        super().__init__(str(uuid.uuid4()))
        self._future = None
        self._function = function
        self._result = None
        self._status = None
        self._args = args
        self._kwargs = kwargs

    def _submit(self):
        if self._future is not None:
            raise JobError("Primitive job has been submitted already.")

        self._future = _SynchronousFuture(self._function, *self._args, **self._kwargs)

    def __getstate__(self):
        _ = self.result()
        _ = self.status()
        state = self.__dict__.copy()
        state["_future"] = None
        return state

    def __setstate__(self, state):
        self.__dict__.update(state)
        self._future = None

    def result(self) -> ResultT:
        if self._result is None:
            self._check_submitted()
            self._result = self._future.result()
        return self._result

    def status(self) -> JobStatus:
        if self._status is None:
            self._check_submitted()
            if self._future.running():
                # we should not store status running because it is not completed
                return JobStatus.RUNNING
            elif self._future.cancelled():
                self._status = JobStatus.CANCELLED
            elif self._future.done() and self._future.exception() is None:
                self._status = JobStatus.DONE
            else:
                self._status = JobStatus.ERROR
        return self._status

    def _check_submitted(self):
        if self._future is None:
            raise JobError("Primitive Job has not been submitted yet.")

    def cancel(self):
        self._check_submitted()
        return self._future.cancel()

    def done(self) -> bool:
        return self.status() == JobStatus.DONE

    def running(self) -> bool:
        return self.status() == JobStatus.RUNNING

    def cancelled(self) -> bool:
        return self.status() == JobStatus.CANCELLED

    def in_final_state(self) -> bool:
        return self.status() in JOB_FINAL_STATES
