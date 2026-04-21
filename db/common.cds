namespace mm.common;

type Status : String(20);

type PRStatus : Status enum {
    DRAFT;
    SUBMITTED;
    IN_APPROVAL;
    APPROVED;
    REJECTED;
};

type POStatus : Status enum {
    CREATED;
    SENT_TO_VENDOR;
    PARTIALLY_RECEIVED;
    COMPLETED;
};

type GRStatus : Status enum {
    PENDING;
    POSTED;
};

type UserRole : String enum {
    EMPLOYEE;
    MANAGER;
};