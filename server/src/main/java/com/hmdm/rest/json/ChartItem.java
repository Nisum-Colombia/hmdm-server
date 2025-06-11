package com.hmdm.rest.json;

public class ChartItem {
    private String stringAttr;
    private long number;

    public ChartItem() {
    }

    public ChartItem(String stringAttr, long number) {
        this.stringAttr = stringAttr;
        this.number = number;
    }

    public String getStringAttr() {
        return stringAttr;
    }

    public void setStringAttr(String stringAttr) {
        this.stringAttr = stringAttr;
    }

    public long getNumber() {
        return number;
    }

    public void setNumber(long number) {
        this.number = number;
    }
}
