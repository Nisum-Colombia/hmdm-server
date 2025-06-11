package com.hmdm.persistence.domain;

public class CustomerEnrollmentStats {
    private int customerId;
    private int enrollmentCount;

    public CustomerEnrollmentStats() {
    }

    public CustomerEnrollmentStats(int customerId, int enrollmentCount) {
        this.customerId = customerId;
        this.enrollmentCount = enrollmentCount;
    }

    public int getCustomerId() {
        return customerId;
    }

    public void setCustomerId(int customerId) {
        this.customerId = customerId;
    }

    public int getEnrollmentCount() {
        return enrollmentCount;
    }

    public void setEnrollmentCount(int enrollmentCount) {
        this.enrollmentCount = enrollmentCount;
    }
}
