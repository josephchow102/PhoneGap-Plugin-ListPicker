package com.oursky.plugins;

import java.lang.Runnable;
import java.util.ArrayList;

import org.json.JSONObject;
import org.json.JSONArray;
import org.json.JSONException;

import android.app.AlertDialog;
import android.content.Context;
import android.content.DialogInterface;

import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaInterface;
import org.apache.cordova.PluginResult;

/**
 * This class provides a service.
 */
public class ListPicker extends CordovaPlugin {

    /**
     * Private Class;
     */
    private static class Picker {
        final int depth;
        final Context context;
        final String title;
        final Items items;
        final AlertDialog.Builder builder;

        int selected;
        DialogInterface.OnClickListener doneClickListener;

        DialogInterface.OnClickListener onClickListener = new DialogInterface.OnClickListener() {
            @Override
            public void onClick(final DialogInterface dialog, final int which) {
                selected = which;
                if (items.items.get(which).nextItems == null) {
                    doneClickListener.onClick(dialog, which);
                } else {
                    final Items nextItems = items.items.get(which).nextItems;
                    Picker picker = new Picker(context, nextItems, null, depth + 1);

                    picker.doneClickListener = new DialogInterface.OnClickListener() {
                        @Override
                        public void onClick(DialogInterface childDialog, int childWhich) {
                            nextItems.selected = childWhich;
                            doneClickListener.onClick(dialog, which);
                            childDialog.dismiss();
                        }
                    };

                    picker.show();
                }
            }
        };

        public Picker(Context context, final Items items, String title, final Runnable doneRunnable, final DialogInterface.OnCancelListener cancelListener) {
            this(context, items, title, 0);
            this.doneClickListener = new DialogInterface.OnClickListener() {
                @Override
                public void onClick(DialogInterface dialog, int which) {
                    items.selected = which;
                    dialog.dismiss();
                    doneRunnable.run();
                }
            };
            this.builder.setOnCancelListener(cancelListener);
        }

        private Picker(Context context, Items items, String title, int depth) {
            this.builder = new AlertDialog.Builder(context);
            this.context = context;
            this.items = items;
            this.title = title;
            this.depth = depth;

            builder.setTitle(title);
            builder.setSingleChoiceItems(items.texts(), items.selected, onClickListener);
        }

        public void show() {
            AlertDialog dialog = this.builder.create();
            dialog.getWindow().getAttributes().windowAnimations = android.R.style.Animation_Dialog;
            dialog.show();
        }
    }

    private static class Items {
        ArrayList<Item> items;
        int selected;

        public Items(JSONArray items, ArrayList<String> selectedValue) throws JSONException {
            this.items = new ArrayList<Item>();
            this.selected = 0;

            String selected = null;
            ArrayList<String> newSelectedValue = null;
            if (selectedValue != null && selectedValue.size() > 0) {
                selected = selectedValue.get(0);
                newSelectedValue = (ArrayList<String>) selectedValue.clone();
                newSelectedValue.remove(0);
            }
            for (int i = 0; i < items.length(); i++) {
                Item item = new Item(items.getJSONObject(i), newSelectedValue);
                if (selected != null && selected.equals(item.value)) {
                    this.selected = i;
                }
                this.items.add(item);
            }
        }

        public CharSequence[] texts() {
            ArrayList<String> texts = new ArrayList<String>();
            for (Item item : this.items) {
                texts.add(item.text);
            }
            return texts.toArray(new CharSequence[texts.size()]);
        }

        public ArrayList<String> selectedValues() {
            ArrayList<String> selectedValues;
            if (this.items.get(this.selected).nextItems == null) {
                selectedValues = new ArrayList<String>();
            } else {
                selectedValues = this.items.get(this.selected).nextItems.selectedValues();
            }
            selectedValues.add(0, this.items.get(this.selected).value);
            return selectedValues;
        }
    }

    private static class Item {
        String text;
        String value;
        Items nextItems;

        public Item(JSONObject jsonObject, ArrayList<String> selectedValue) throws JSONException {
            this.text = jsonObject.getString("text");
            this.value = jsonObject.getString("value");
            if (jsonObject.has("next")) {
                this.nextItems = new Items(jsonObject.getJSONObject("next").getJSONArray("items"), selectedValue);
            }
        }
    }

    /**
     * Constructor.
     */
    public ListPicker() {
    }

    /**
     * Executes the request and returns PluginResult.
     *
     * @param action        The action to execute.
     * @param args          JSONArry of arguments for the plugin.
     * @param callbackId    The callback id used when calling back into JavaScript.
     * @return              A PluginResult object with a status and message.
     */
    @Override
    public boolean execute(String action, JSONArray args, final CallbackContext callbackContext) throws JSONException {
        if (action.equals("showPicker")) {
            this.showPicker(args, callbackContext);
            return true;
        }
        return false;
    }

    // --------------------------------------------------------------------------
    // LOCAL METHODS
    // --------------------------------------------------------------------------

    private void showPicker(final JSONArray data, final CallbackContext callbackContext) throws JSONException {

        final CordovaInterface cordova = this.cordova;

        final JSONObject options = data.getJSONObject(0);

        final String title = options.getString("title");
        final Items items = new Items(
                options.getJSONArray("items"),
                convertJSONArray(options.getJSONArray("selectedValue"))
        );

        this.cordova.getActivity().runOnUiThread(new Runnable() {
            @Override
            public void run() {
                Picker picker = new Picker(cordova.getActivity(), items, title, new Runnable() {
                    @Override
                    public void run() {
                        ArrayList<String> selectedValues = items.selectedValues();
                        JSONArray selectedJsonArray = new JSONArray(selectedValues);
                        callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK, selectedJsonArray));
                    }
                }, new DialogInterface.OnCancelListener() {
                    @Override
                    public void onCancel(DialogInterface dialog) {
                        callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.ERROR));
                    }
                });
                picker.show();
            }
        });
    }

    private static ArrayList<String> convertJSONArray(JSONArray jsonArray) throws JSONException {
        ArrayList<String> list = new ArrayList<String>();
        if (jsonArray != null) {
            int len = jsonArray.length();
            for (int i=0;i<len;i++){
                list.add(jsonArray.get(i).toString());
            }
        }
        return list;
    }
}
