module c3api::server;

import std::collections::list;
import std::thread;
import std::io;

struct Worker {
    Thread thread;
    bool terminate;
    WorkQueue* queue;
}

def Data = void*;
def Function = fn int(Data);

struct Job {
    Function function;
    Data data;
}

struct WorkQueue {
    List(<Worker*>) workers;
    List(<Job*>) pendingJobs;
    Mutex jobsMutex;
    ConditionVariable jobsCond;
}

fn int executeWorker(Data data) {
    Worker* worker = data;

    while (true) {
        worker.queue.jobsMutex.lock() !!;

        if (worker.terminate) break;

        worker.queue.jobsCond.wait(&worker.queue.jobsMutex) !!;

        if (worker.terminate) break;

        if (worker.queue.pendingJobs.len() == 0) continue;

        Job* job = worker.queue.pendingJobs.pop_first()!!;

        worker.queue.jobsMutex.unlock() !!;

        job.function(job.data);
    }

    worker.queue.jobsMutex.unlock() !!;

    return 0;
}

fn void WorkQueue.add(WorkQueue* self, Function function, Data data) {
    Job job;
    job.function = function;
    job.data = data;

    self.jobsMutex.lock() !!;

    self.pendingJobs.push(allocator::clone(&allocator::LIBC_ALLOCATOR, job));

    self.jobsCond.signal() !!;
    self.jobsMutex.unlock() !!;
}

fn void WorkQueue.init(WorkQueue* self, int workers) {
    self.jobsMutex.init() !!;
    self.jobsCond.init() !!;

    for (int i = 0; i < workers; i++) {
        Worker worker;
        worker.queue = self;
        worker.terminate = false;

        io::printf("Starting Worker #%d... ", i);
        Worker* clone = allocator::clone(&allocator::LIBC_ALLOCATOR, worker);
        if (catch anyfault err = worker.thread.create(&executeWorker, (Data) clone)) {
            io::eprintfn("Failure to create a worker thread: %p.", (Data) clone);
            return;
        }
        io::printn("Success");
        self.workers.push(clone);
    }
}

fn void WorkQueue.free(WorkQueue* self) {

}

fn void WorkQueue.terminate(WorkQueue* self) {
    foreach (Worker* worker: self.workers) {
        worker.terminate = true;
    }

    self.jobsMutex.lock() !!;
    self.jobsCond.broadcast() !!;
    self.jobsMutex.unlock() !!;

    foreach (Worker* worker: self.workers) {
        worker.thread.join() !!;
    }

    self.jobsMutex.lock() !!;

    foreach (Worker* worker: self.workers) {
        if (worker == null) continue;
        free(worker);
    }

    foreach (Job* job: self.pendingJobs) {
        if (job == null) continue;
        free(job.data);
        free(job);
    }

    self.workers.free();
    self.pendingJobs.free();

    self.jobsMutex.unlock() !!;

    self.jobsCond.destroy() !!;
    self.jobsMutex.destroy() !!;
}
